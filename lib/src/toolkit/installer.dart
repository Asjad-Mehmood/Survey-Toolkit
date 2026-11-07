// Installing, updating and removing the tools (T3), the way T0 found each one works
// (docs/TOOLS.md):
//
//   1. The download comes from the website's feed: only from www.exceltokml.com or the owner's
//      GitHub releases, over HTTPS. It is saved under %LOCALAPPDATA%\Survey Toolkit\downloads and
//      its SHA-256 is checked; a download that doesn't match is deleted and nothing is installed.
//   2. A program that is open is never installed over: its installer would close it by force
//      (unsaved work lost), so the user is asked to close it first.
//   3. Excel to KML, Traverse & Level, Slope Calculator: their official installer, run with /S.
//      RoadPro: an AutoCAD bundle in %APPDATA%\Autodesk\ApplicationPlugins, which AutoCAD loads by
//      itself at start-up. Project Folder Manager: unzipped into the Toolkit's folder with a
//      Start menu shortcut, keeping the user's settings file.
//   4. Afterwards the tool is looked for again: the job only counts as done when the new version
//      is there.
// Every step goes into %LOCALAPPDATA%\Survey Toolkit\toolkit.log for support.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'detect.dart';
import 'feed.dart';
import 'version.dart';

/// Runs a program and waits for that process only (not for a program it opens); its exit code
typedef RunProgram = Future<int> Function(String exe, List<String> args);

/// Is a program with this file name (ExcelToKML.exe) running?
typedef IsRunning = Future<bool> Function(String exeName);

/// Makes a Windows shortcut (.lnk)
typedef MakeShortcut = Future<void> Function({required String link, required String target, required String folder});

/// From `tasklist /FI "IMAGENAME eq X" /NH /FO CSV`: is X in the list?
bool tasklistHas(String output, String exeName) {
  final want = '"${exeName.toLowerCase()}"';
  return output.toLowerCase().split(RegExp(r'\r?\n')).any((l) => l.trimLeft().startsWith(want));
}

/// What a job is doing now, for the card's progress bar
class JobProgress {
  const JobProgress(this.step, [this.fraction]);
  final String step;

  /// 0..1 while downloading; null when it can't be measured
  final double? fraction;
}

class JobResult {
  const JobResult.done(this.message, {this.version}) : ok = true, blocked = false;
  const JobResult.failed(this.message) : ok = false, blocked = false, version = null;

  /// The tool is open: nothing was done, the user closes it and tries again
  const JobResult.blocked(this.message) : ok = false, blocked = true, version = null;

  final bool ok;
  final bool blocked;
  final String message;

  /// The version found afterwards
  final String? version;
}

class _Refused implements Exception {
  _Refused(this.message);
  final String message;
}

class ToolInstaller {
  ToolInstaller({
    required this.places,
    required this.detector,
    http.Client? client,
    RunProgram? run,
    IsRunning? isRunning,
    MakeShortcut? shortcut,
    this.maxDownloadBytes = 500 * 1024 * 1024,
    this.waitForUninstall = const Duration(seconds: 60),
    this.waitForInstall = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _run = run ?? runAndWait,
       _isRunning = isRunning ?? windowsIsRunning,
       _shortcut = shortcut ?? windowsShortcut;

  final Places places;
  final Detector detector;
  final http.Client _client;
  final RunProgram _run;
  final IsRunning _isRunning;
  final MakeShortcut _shortcut;
  final int maxDownloadBytes;
  final Duration waitForUninstall;

  /// How long the new version may take to show after its installer has finished
  final Duration waitForInstall;

  // ------------------------------------------------------------------ install / update

  Future<JobResult> install(FeedTool t, {Installed? current, void Function(JobProgress)? onProgress}) async {
    final progress = onProgress ?? (_) {};
    final from = current?.version;
    log('${from == null ? 'install' : 'update'} ${t.id} ${from ?? '-'} -> ${t.version ?? '?'}');
    final dl = t.download;
    if (dl == null || t.version == null) {
      return _fail(
        t,
        'The download for ${t.name} can\'t be checked just now, so it wasn\'t installed. Try again later.',
      );
    }
    if (!isAllowedDownload(dl.url)) {
      return _fail(t, 'The download address for ${t.name} is not one the Toolkit trusts.');
    }

    final open = await _openProgram(t, current);
    if (open != null) {
      log('  blocked: $open is running');
      return JobResult.blocked('Close ${t.name} first, then press ${from == null ? 'Install' : 'Update'} again.');
    }

    File? file;
    try {
      progress(const JobProgress('Downloading', 0));
      file = await _download(dl, (f) => progress(JobProgress('Downloading', f)));
      progress(const JobProgress('Installing'));
      switch (t.install.kind) {
        case 'installer':
          final code = await _run(file.path, t.install.quietArgs.isEmpty ? const ['/S'] : t.install.quietArgs);
          log('  installer exit $code');
          if (code != 0) throw _Refused('The ${t.name} installer stopped (code $code). Nothing else was changed.');
        case 'autocad-bundle':
          await _installBundle(t, await file.readAsBytes());
        case 'zip':
          await _installZip(t, await file.readAsBytes(), current);
        default:
          throw _Refused('The Toolkit doesn\'t know how to install ${t.name}.');
      }
      progress(const JobProgress('Checking'));
      final found = await _waitFor(t, (i) => i.found && compareVersions(i.version!, t.version!) == 0, waitForInstall);
      if (found == null) {
        final now = await detector.find(t);
        throw _Refused(
          now.found
              ? '${t.name} was installed, but the version found is ${now.version}, not ${t.version}.'
              : '${t.name} was installed, but it can\'t be found on this PC afterwards.',
        );
      }
      log('  done: ${found.version}');
      if (current != null && current.oldCopy) _removeOldCopy(t, current);
      final note = t.install.kind == 'autocad-bundle' && await _isRunning('acad.exe')
          ? ' AutoCAD loads it the next time it starts.'
          : '';
      return JobResult.done(
        from == null
            ? '${t.name} ${found.version} is installed.$note'
            : '${t.name} is updated to ${found.version}.$note',
        version: found.version,
      );
    } on _Refused catch (e) {
      return _fail(t, e.message);
    } catch (e) {
      return _fail(t, '${t.name} could not be installed: $e');
    } finally {
      if (file != null && file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {
          // an installer may still hold it a moment; it is replaced next time
        }
      }
    }
  }

  JobResult _fail(FeedTool t, String message) {
    log('  failed: $message');
    return JobResult.failed(message);
  }

  /// The tool's program, when it is running (installers close it by force)
  Future<String?> _openProgram(FeedTool t, [Installed? current]) async {
    final names = switch (t.install.kind) {
      'installer' => [...t.install.exe, if (current?.program != null) p.basename(current!.program!)],
      'zip' => [?t.install.main],
      _ => const <String>[],
    };
    for (final n in names) {
      if (await _isRunning(n)) return n;
    }
    return null;
  }

  /// Downloads to the Toolkit's downloads folder, checking size and SHA-256 as it goes
  Future<File> _download(FeedDownload dl, void Function(double?) onFraction) async {
    Directory(places.downloads).createSync(recursive: true);
    final name = p.basename(dl.file).replaceAll(RegExp(r'[^A-Za-z0-9_.()-]'), '_');
    final part = File(p.join(places.downloads, '$name.part'));
    final res = await _client.send(http.Request('GET', Uri.parse(dl.url))).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw _Refused('The download answered ${res.statusCode}. Nothing was installed.');
    final total = dl.size ?? res.contentLength;
    final sink = part.openWrite();
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var got = 0;
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        got += chunk.length;
        if (got > maxDownloadBytes) throw _Refused('The download is larger than expected, so it was stopped.');
        hasher.add(chunk);
        sink.add(chunk);
        onFraction(total != null && total > 0 ? (got / total).clamp(0, 1).toDouble() : null);
      }
    } finally {
      await sink.close();
      hasher.close();
    }
    final sum = digest.value.toString();
    log('  downloaded $got bytes, sha256 $sum');
    if (dl.size != null && got != dl.size) {
      part.deleteSync();
      throw _Refused('The download was incomplete ($got of ${dl.size} bytes). Nothing was installed.');
    }
    if (sum != dl.sha256) {
      part.deleteSync();
      throw _Refused('The download didn\'t match its SHA-256 checksum, so it was deleted and nothing was installed.');
    }
    final file = File(p.join(places.downloads, name));
    if (file.existsSync()) file.deleteSync();
    return part.renameSync(file.path);
  }

  /// The files of a zip by their plain names (folders inside the zip and odd names are ignored)
  Map<String, List<int>> _unzip(List<int> bytes, List<String> expected) {
    final out = <String, List<int>>{};
    for (final f in ZipDecoder().decodeBytes(bytes)) {
      if (!f.isFile) continue;
      final name = p.basename(f.name.replaceAll('\\', '/'));
      if (name.isEmpty || name.startsWith('.')) continue;
      out[name] = f.content;
    }
    final missing = expected.where((e) => !out.containsKey(e)).toList();
    if (missing.isNotEmpty) throw _Refused('The download is missing ${missing.join(', ')}. Nothing was installed.');
    return out;
  }

  Future<void> _installBundle(FeedTool t, List<int> zip) async {
    final files = _unzip(zip, t.install.files);
    final bundle = places.roadproBundle;
    final fresh = Directory('$bundle.new');
    if (fresh.existsSync()) fresh.deleteSync(recursive: true);
    final contents = Directory(p.join(fresh.path, 'Contents'))..createSync(recursive: true);
    for (final name in t.install.files) {
      File(p.join(contents.path, name)).writeAsBytesSync(files[name]!, flush: true);
    }
    File(p.join(fresh.path, 'PackageContents.xml'))
        .writeAsStringSync(packageContents(t.version!, t.install.main ?? 'RoadPro.lsp'));
    _swapIn(fresh, Directory(bundle));
    log('  bundle in $bundle');
  }

  /// Puts [fresh] where [target] is, keeping the old one until the new one is in place
  void _swapIn(Directory fresh, Directory target) {
    final old = Directory('${target.path}.old');
    if (old.existsSync()) old.deleteSync(recursive: true);
    final hadOld = target.existsSync();
    if (hadOld) target.renameSync(old.path);
    try {
      fresh.renameSync(target.path);
    } catch (e) {
      if (hadOld) old.renameSync(target.path);
      rethrow;
    }
    if (hadOld) {
      try {
        old.deleteSync(recursive: true);
      } catch (_) {
        // a file still open in AutoCAD: removed next time
      }
    }
  }

  Future<void> _installZip(FeedTool t, List<int> zip, Installed? current) async {
    final files = _unzip(zip, t.install.files);
    // an update goes where the tool is; a new install into the Toolkit's folder
    final folder = current?.folder ?? places.folderManager;
    Directory(folder).createSync(recursive: true);
    for (final name in t.install.files) {
      if (t.install.keep.contains(name)) continue;
      File(p.join(folder, name)).writeAsBytesSync(files[name]!, flush: true);
    }
    log('  unzipped into $folder (kept ${t.install.keep.join(', ')})');
    if (p.equals(folder, places.folderManager) && t.install.main != null) {
      try {
        Directory(places.startMenu).createSync(recursive: true);
        await _shortcut(
          link: p.join(places.startMenu, '${t.name}.lnk'),
          target: p.join(folder, t.install.main!),
          folder: folder,
        );
      } catch (e) {
        log('  no Start menu shortcut: $e');
      }
    }
  }

  /// After Project Folder Manager 7 is installed over a 6.2 copy the Toolkit unzipped: that copy's
  /// program files and Start menu shortcut go. Its settings file stays, so version 7 can offer to
  /// bring the settings in. A copy the user unzipped somewhere else is left as it is.
  void _removeOldCopy(FeedTool t, Installed old) {
    if (old.folder == null || !p.equals(old.folder!, places.folderManager)) {
      log('  the old copy in ${old.folder} was not installed by the Toolkit: left as it is');
      return;
    }
    try {
      for (final name in folderManagerZip.files) {
        final f = File(p.join(old.folder!, name));
        if (f.existsSync()) f.deleteSync();
      }
      final link = File(p.join(places.startMenu, '${t.name}.lnk'));
      if (link.existsSync()) link.deleteSync();
      final menu = Directory(places.startMenu);
      if (menu.existsSync() && menu.listSync().isEmpty) menu.deleteSync();
      final dir = Directory(old.folder!);
      if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
      log('  the old copy is removed (its settings file is kept)');
    } catch (e) {
      log('  the old copy could not be removed completely: $e');
    }
  }

  /// Looks again until [test] holds or [limit] passes
  Future<Installed?> _waitFor(FeedTool t, bool Function(Installed) test, Duration limit) async {
    final until = DateTime.now().add(limit);
    while (true) {
      final i = await detector.find(t);
      if (test(i)) return i;
      if (DateTime.now().isAfter(until)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  // ------------------------------------------------------------------ uninstall

  /// Whether the Toolkit can remove this copy (and if not, why)
  String? cannotUninstall(FeedTool t, Installed i) {
    if (!i.found) return '${t.name} is not installed.';
    if (i.oldCopy) {
      return 'This is the old version ${i.version} of ${t.name}. Press Update to replace it with the new program, '
          'or delete its folder yourself if you no longer need it.';
    }
    if (t.install.kind == 'zip' && (i.folder == null || !p.equals(i.folder!, places.folderManager))) {
      return 'This copy of ${t.name} was not installed by the Toolkit. Delete its folder yourself if you no longer need it.';
    }
    if (t.install.kind == 'installer' && (i.folder == null || !File(p.join(i.folder!, 'Uninstall.exe')).existsSync())) {
      return '${t.name}\'s uninstaller was not found. Remove it from Windows Settings → Apps.';
    }
    return null;
  }

  Future<JobResult> uninstall(FeedTool t, Installed current) async {
    log('uninstall ${t.id} ${current.version}');
    final why = cannotUninstall(t, current);
    if (why != null) return _fail(t, why);
    final open = await _openProgram(t);
    if (open != null) return JobResult.blocked('Close ${t.name} first, then press Uninstall again.');
    try {
      switch (t.install.kind) {
        case 'installer':
          // NSIS uninstallers hand over to a copy of themselves and return at once: wait until gone
          final code = await _run(p.join(current.folder!, 'Uninstall.exe'), const ['/S']);
          log('  uninstaller exit $code');
          if (await _waitFor(t, (i) => !i.found, waitForUninstall) == null) {
            throw _Refused('${t.name}\'s uninstaller ran, but ${t.name} is still listed in Windows.');
          }
        case 'autocad-bundle':
          final b = Directory(places.roadproBundle);
          if (b.existsSync()) b.deleteSync(recursive: true);
        case 'zip':
          final folder = current.folder!;
          for (final name in t.install.files) {
            final f = File(p.join(folder, name));
            if (f.existsSync()) f.deleteSync();
          }
          final link = File(p.join(places.startMenu, '${t.name}.lnk'));
          if (link.existsSync()) link.deleteSync();
          final dir = Directory(folder);
          if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
      }
      log('  removed');
      final kept = t.install.kind == 'zip' && t.install.keep.any((k) => File(p.join(current.folder!, k)).existsSync());
      return JobResult.done('${t.name} is removed.${kept ? ' Your settings file is kept for next time.' : ''}');
    } on _Refused catch (e) {
      return _fail(t, e.message);
    } catch (e) {
      return _fail(t, '${t.name} could not be removed: $e');
    }
  }

  // ------------------------------------------------------------------ the log

  void log(String line) {
    try {
      final f = File(places.log);
      f.parent.createSync(recursive: true);
      if (f.existsSync() && f.lengthSync() > 1024 * 1024) f.renameSync('${places.log}.1');
      f.writeAsStringSync('${DateTime.now().toIso8601String()} $line\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // a log that can't be written never stops a job
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// The AutoCAD bundle's description: load RoadPro.lsp at start-up, AutoCAD 2014 (R19.1) or newer
String packageContents(String version, String main) {
  const esc = HtmlEscape(HtmlEscapeMode.attribute);
  final v = esc.convert(version), m = esc.convert(main);
  return '''<?xml version="1.0" encoding="utf-8"?>
<ApplicationPackage SchemaVersion="1.0" AppVersion="$v" Name="RoadPro"
  Description="RoadPro, the road builder for AutoCAD. Installed by the Survey Toolkit."
  Author="Excel to KML" AutodeskProduct="AutoCAD" ProductType="Application"
  ProductCode="{6B1A3C52-2F0E-4E8B-9C41-52A7D3F0B1E4}" UpgradeCode="{0C5E9D17-8A4B-4F63-B2E1-7D9A6C3E5F20}">
  <CompanyDetails Name="Excel to KML" Url="https://www.exceltokml.com/roadpro" />
  <RuntimeRequirements OS="Win64" Platform="AutoCAD*" SeriesMin="R19.1" />
  <Components Description="RoadPro">
    <RuntimeRequirements OS="Win64" Platform="AutoCAD*" SeriesMin="R19.1" />
    <ComponentEntry AppName="RoadPro" Version="$v" ModuleName="./Contents/$m" AppDescription="RoadPro road builder" LoadOnAutoCADStartup="True" />
  </Components>
</ApplicationPackage>
''';
}

// ------------------------------------------------------------------ Windows

/// Waits for the process itself only: an installer that opens its program at the end returns
Future<int> runAndWait(String exe, List<String> args) async {
  final proc = await Process.start(exe, args);
  unawaited(proc.stdout.drain<void>());
  unawaited(proc.stderr.drain<void>());
  return proc.exitCode.timeout(const Duration(minutes: 10));
}

Future<bool> windowsIsRunning(String exeName) async {
  try {
    final r = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $exeName', '/NH', '/FO', 'CSV']);
    return r.exitCode == 0 && tasklistHas(r.stdout as String, exeName);
  } catch (_) {
    return false;
  }
}

Future<void> windowsShortcut({required String link, required String target, required String folder}) async {
  String q(String s) => s.replaceAll("'", "''");
  final script =
      "\$s=(New-Object -ComObject WScript.Shell).CreateShortcut('${q(link)}');"
      "\$s.TargetPath='${q(target)}';\$s.WorkingDirectory='${q(folder)}';\$s.Save()";
  final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
  if (r.exitCode != 0) throw ProcessException('powershell', const [], '${r.stderr}', r.exitCode);
}
