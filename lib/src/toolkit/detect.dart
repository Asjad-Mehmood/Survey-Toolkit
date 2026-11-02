// Finding what is installed on this PC, read-only (T0's docs/TOOLS.md):
//   Excel to KML, Traverse & Level, Slope Calculator: their entry in Settings → Apps, that is
//     HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<key>, value DisplayVersion.
//   RoadPro: the AutoCAD bundle the Toolkit will install (T3),
//     %APPDATA%\Autodesk\ApplicationPlugins\RoadPro.bundle, version on line 3 of RoadPro.lsp.
//   Project Folder Manager: the Toolkit's folder, or one the user chose, version inside the .hta.
// The parsing is kept apart from Windows so it can be tested anywhere.
import 'dart:io';

import 'package:path/path.dart' as p;

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

/// Where things are on this PC. Real Windows folders in the program; a temporary folder in tests.
class Places {
  Places({required this.localAppData, required this.appData});

  factory Places.windows([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    return Places(localAppData: env['LOCALAPPDATA'] ?? '', appData: env['APPDATA'] ?? '');
  }

  final String localAppData;
  final String appData;

  /// The Toolkit's own folder: %LOCALAPPDATA%\Survey Toolkit (the program itself is in Program)
  String get toolkit => p.join(localAppData, 'Survey Toolkit');
  String get downloads => p.join(toolkit, 'downloads');
  String get log => p.join(toolkit, 'toolkit.log');

  /// Project Folder Manager, installed by the Toolkit
  String get folderManager => p.join(toolkit, 'apps', 'Project Folder Manager');

  /// RoadPro as an AutoCAD bundle: AutoCAD loads it by itself at start-up
  String get roadproBundle => p.join(appData, 'Autodesk', 'ApplicationPlugins', 'RoadPro.bundle');

  /// The Start menu folder for what the Toolkit installs without an installer
  String get startMenu => p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Survey Toolkit');
}

/// Reads one registry key's values; null when it isn't there
typedef RegistryReader = Future<Map<String, String>?> Function(String key);

/// reg.exe, on Windows
Future<Map<String, String>?> readRegistry(String key) async {
  try {
    final r = await Process.run('reg', ['query', key], stdoutEncoding: systemEncoding);
    if (r.exitCode != 0) return null;
    return parseRegQuery(r.stdout as String);
  } catch (_) {
    return null;
  }
}

/// Windows: the registry for the three installers, the files under AppData for the other two
class WindowsDetector implements Detector {
  WindowsDetector({String? Function()? folderManagerFolder, Places? places, RegistryReader? registry})
    : folderManagerFolder = folderManagerFolder ?? (() => null),
      places = places ?? Places.windows(),
      _reg = registry ?? readRegistry;

  /// A folder the user chose for a Project Folder Manager they unzipped themselves
  final String? Function() folderManagerFolder;
  final Places places;
  final RegistryReader _reg;

  static const uninstallRoot = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall';

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
            if (File(p.join(folder, exe)).existsSync()) {
              program = p.join(folder, exe);
              break;
            }
          }
        }
        return Installed(version: v, folder: folder, program: program);
      case 'autocad-bundle':
        final lsp = File(p.join(places.roadproBundle, 'Contents', i.main ?? 'RoadPro.lsp'));
        final autocad = await hasAutocad();
        final note = autocad ? null : 'AutoCAD not found on this PC';
        if (!lsp.existsSync()) return Installed(note: note);
        return Installed(version: lspVersion(_head(lsp)) ?? '0', folder: places.roadproBundle, note: note);
      case 'zip':
        for (final folder in [?folderManagerFolder(), places.folderManager]) {
          final hta = File(p.join(folder, 'Project_Folder_Manager.hta'));
          if (!hta.existsSync()) continue;
          final v = htaVersion(_head(hta, 400 * 1024));
          final exe = File(p.join(folder, i.main ?? 'Project_Folder_Manager.exe'));
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
        return String.fromCharCodes(raf.readSync(max));
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
