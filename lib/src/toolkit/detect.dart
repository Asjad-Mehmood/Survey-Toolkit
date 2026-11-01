// Finding what is installed on this PC, read-only (T0's docs/TOOLS.md):
//   Excel to KML, Traverse & Level, Slope Calculator: their entry in Settings → Apps, that is
//     HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>, value DisplayVersion.
//   RoadPro: the AutoCAD bundle the Toolkit will install (T3),
//     %APPDATA%\Autodesk\ApplicationPlugins\RoadPro.bundle, version on line 3 of RoadPro.lsp.
//   Project Folder Manager: the Toolkit's folder, or one the user chose, version inside the .hta.
// The parsing is kept apart from Windows so it can be tested anywhere.
import 'dart:io';

import 'feed.dart';
import 'version.dart';

class Installed {
  const Installed({this.version, this.folder, this.program, this.note});

  /// Not found on this PC
  static const none = Installed();

  /// null when not installed
  final String? version;
  final String? folder;

  /// The program to open, when there is one
  final String? program;

  /// Something to tell the user ("AutoCAD not found")
  final String? note;

  bool get found => version != null;

  Map<String, Object?> toJson() => {
    'version': version,
    if (folder != null) 'folder': folder,
    if (program != null) 'program': program,
    if (note != null) 'note': note,
  };
}

/// The values under a key, from the output of `reg query <key>`:
///     DisplayVersion    REG_SZ    4.4.0
Map<String, String> parseRegQuery(String output) {
  final values = <String, String>{};
  final line = RegExp(r'^\s{2,}(.+?)\s{2,}(REG_[A-Z_]+)\s{2,}(.*)$');
  for (final l in output.split(RegExp(r'\r?\n'))) {
    final m = line.firstMatch(l);
    if (m != null) values[m.group(1)!.trim()] = m.group(3)!.trim();
  }
  return values;
}

/// RoadPro's version from RoadPro.lsp: ";;;  Version : 3.4    Date : 23-Oct-2026"
String? lspVersion(String text) {
  final m = RegExp(r'Version\s*:\s*(\d+(?:\.\d+){0,3})').firstMatch(text);
  return m?.group(1);
}

/// Project Folder Manager's version from its .hta: "PROJECT FOLDER MANAGER  v6.2"
String? htaVersion(String text) {
  final m = RegExp(r'PROJECT FOLDER MANAGER\s+v(\d+(?:\.\d+){0,3})', caseSensitive: false).firstMatch(text);
  return m?.group(1);
}

/// A path from the registry without the quotes some installers put round it
String unquote(String s) {
  final t = s.trim();
  return t.length >= 2 && t.startsWith('"') && t.endsWith('"') ? t.substring(1, t.length - 1) : t;
}

abstract class Detector {
  Future<Installed> find(FeedTool tool);

  /// Full AutoCAD (or Civil 3D, Map 3D) on this PC: RoadPro needs it
  Future<bool> hasAutocad();
}

/// Windows: reads the registry with reg.exe and the files under AppData
class WindowsDetector implements Detector {
  WindowsDetector({String? Function()? folderManagerFolder, Map<String, String>? environment})
    : folderManagerFolder = folderManagerFolder ?? (() => null),
      _env = environment ?? Platform.environment;

  /// A folder the user chose for a Project Folder Manager they unzipped themselves
  final String? Function() folderManagerFolder;
  final Map<String, String> _env;

  static const uninstallRoot = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall';

  String get toolkitFolder => '${_env['LOCALAPPDATA'] ?? ''}\\Survey Toolkit';
  String get roadproBundle => '${_env['APPDATA'] ?? ''}\\Autodesk\\ApplicationPlugins\\RoadPro.bundle';
  String get folderManagerDefault => '$toolkitFolder\\apps\\Project Folder Manager';

  Future<Map<String, String>?> _reg(String key) async {
    try {
      final r = await Process.run('reg', ['query', key], stdoutEncoding: systemEncoding);
      if (r.exitCode != 0) return null;
      return parseRegQuery(r.stdout as String);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Installed> find(FeedTool tool) async {
    final i = tool.install;
    switch (i.kind) {
      case 'installer':
        final apps = await _reg('$uninstallRoot\\${i.registryKey}');
        final v = apps?['DisplayVersion'];
        if (apps == null || v == null || !looksLikeVersion(v)) return Installed.none;
        var folder = apps['InstallLocation'];
        if (folder == null || folder.isEmpty) {
          final own = await _reg('HKCU\\Software\\${i.registryKey}');
          folder = own == null ? null : own['InstallDir'];
        }
        folder = folder == null ? null : unquote(folder);
        String? program;
        if (folder != null) {
          for (final exe in i.exe) {
            if (File('$folder\\$exe').existsSync()) {
              program = '$folder\\$exe';
              break;
            }
          }
        }
        return Installed(version: v, folder: folder, program: program);
      case 'autocad-bundle':
        final lsp = File('$roadproBundle\\Contents\\${i.main ?? 'RoadPro.lsp'}');
        final autocad = await hasAutocad();
        if (!lsp.existsSync()) return Installed(note: autocad ? null : 'AutoCAD not found on this PC');
        final v = lspVersion(_head(lsp));
        return Installed(
          version: v ?? '0',
          folder: roadproBundle,
          note: autocad ? null : 'AutoCAD not found on this PC',
        );
      case 'zip':
        for (final folder in [?folderManagerFolder(), folderManagerDefault]) {
          final hta = File('$folder\\Project_Folder_Manager.hta');
          if (!hta.existsSync()) continue;
          final v = htaVersion(_head(hta, 400 * 1024));
          final exe = File('$folder\\${i.main ?? 'Project_Folder_Manager.exe'}');
          return Installed(version: v ?? '0', folder: folder, program: exe.existsSync() ? exe.path : null);
        }
        return Installed.none;
    }
    return Installed.none;
  }

  /// The start of a text file (the version is near the top)
  static String _head(File f, [int max = 8 * 1024]) {
    try {
      final raf = f.openSync();
      try {
        final bytes = raf.readSync(max);
        return String.fromCharCodes(bytes);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool> hasAutocad() async =>
      await _reg(r'HKCU\Software\Autodesk\AutoCAD') != null || await _reg(r'HKLM\SOFTWARE\Autodesk\AutoCAD') != null;
}
