// What the RoadPro panel needs from this PC, read-only apart from starting a program:
//   - the AutoCAD products, from the registry as RoadPro Hub reads them (Road-pro's
//     AutoCadLocator.cs): HKLM\SOFTWARE\Autodesk\AutoCAD\R<xx.x>\ACAD-<id>:<lang>, values
//     ProductName and AcadLocation. AutoCAD LT has its own key and is not listed (RoadPro needs
//     full AutoCAD).
//   - RoadPro Hub, from RoadPro Setup's entry in Settings → Apps (Inno Setup AppId + "_is1").
// The parsing is kept apart from Windows so it can be tested anywhere.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../toolkit/detect.dart';

/// One AutoCAD-based product: AutoCAD, Civil 3D, Map 3D …
class AutocadProduct {
  const AutocadProduct({required this.name, required this.release, required this.folder, this.year});

  final String name;

  /// R24.3
  final String release;
  final int? year;

  /// Where acad.exe is
  final String folder;

  String get exe => p.windows.join(folder, 'acad.exe');

  /// RoadPro needs AutoCAD 2013 (R19.0) or newer
  bool get supported {
    final m = RegExp(r'^R(\d+)\.(\d+)$').firstMatch(release);
    if (m == null) return false;
    final major = int.parse(m.group(1)!), minor = int.parse(m.group(2)!);
    return major > 19 || (major == 19 && minor >= 0);
  }
}

const _years = {
  'R17.0': 2007,
  'R17.1': 2008,
  'R17.2': 2009,
  'R18.0': 2010,
  'R18.1': 2011,
  'R18.2': 2012,
  'R19.0': 2013,
  'R19.1': 2014,
  'R20.0': 2015,
  'R20.1': 2016,
  'R21.0': 2017,
  'R22.0': 2018,
  'R23.0': 2019,
  'R23.1': 2020,
  'R24.0': 2021,
  'R24.1': 2022,
  'R24.2': 2023,
  'R24.3': 2024,
  'R25.0': 2025,
  'R25.1': 2026,
  'R25.2': 2027,
};

/// The values of one name under every subkey, from `reg query <root> /s /v <name>`:
///     HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\ACAD-7101:409
///         AcadLocation    REG_SZ    C:\Program Files\Autodesk\AutoCAD 2024
Map<String, String> parseRegSearch(String output) {
  final values = <String, String>{};
  String? key;
  final value = RegExp(r'^\s{2,}(.+?)\s{2,}(REG_[A-Z_]+)\s{2,}(.*)$');
  for (final l in output.split(RegExp(r'\r?\n'))) {
    if (l.startsWith('HKEY_')) {
      key = l.trim();
      continue;
    }
    final m = value.firstMatch(l);
    if (m != null && key != null) values[key] = m.group(3)!.trim();
  }
  return values;
}

/// The products from the two searches (AcadLocation and ProductName), newest first
List<AutocadProduct> autocadProducts(Map<String, String> locations, Map<String, String> names) {
  final out = <AutocadProduct>[];
  final keyRx = RegExp(r'\\AutoCAD\\(R\d+\.\d+)\\(ACAD-[^\\]+)$', caseSensitive: false);
  for (final e in locations.entries) {
    final m = keyRx.firstMatch(e.key);
    final folder = unquote(e.value);
    if (m == null || folder.isEmpty) continue;
    final release = m.group(1)!.toUpperCase();
    final year = _years[release];
    final name = (names[e.key] ?? '').trim();
    out.add(
      AutocadProduct(
        name: name.isNotEmpty ? name : 'AutoCAD ${year ?? release}',
        release: release,
        year: year,
        folder: folder,
      ),
    );
  }
  double rank(AutocadProduct a) {
    final m = RegExp(r'^R(\d+)\.(\d+)$').firstMatch(a.release)!;
    return double.parse('${m.group(1)}.${m.group(2)}');
  }

  out.sort((a, b) {
    final r = rank(b).compareTo(rank(a));
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

/// RoadPro Setup's entry in Settings → Apps (its Inno Setup AppId, which never changes)
const roadproHubKey =
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6F3B1C52-2B7E-4C0A-9E57-3E1D1B7C9A41}_is1';

abstract class RoadProPc {
  /// The AutoCAD products on this PC, newest first
  Future<List<AutocadProduct>> autocads();

  /// RoadProHub.exe, when RoadPro Setup is installed
  Future<String?> hub();

  /// Starts a program without waiting for it; false when it could not be started
  Future<bool> start(String exe, [List<String> args = const []]);
}

/// reg.exe and the files on this PC
class WindowsRoadProPc implements RoadProPc {
  WindowsRoadProPc({RegistryReader? registry}) : _reg = registry ?? readRegistry;
  final RegistryReader _reg;

  static Future<Map<String, String>> _search(String value) async {
    try {
      final r = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Autodesk\AutoCAD',
        '/s',
        '/v',
        value,
      ], stdoutEncoding: systemEncoding);
      return r.exitCode == 0 ? parseRegSearch(r.stdout as String) : const {};
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<List<AutocadProduct>> autocads() async {
    final found = autocadProducts(await _search('AcadLocation'), await _search('ProductName'));
    return [
      for (final a in found)
        if (File(a.exe).existsSync()) a,
    ];
  }

  @override
  Future<String?> hub() async {
    final v = await _reg(roadproHubKey);
    final folder = v?['InstallLocation'];
    if (folder == null || folder.isEmpty) return null;
    final exe = File(p.join(unquote(folder), 'RoadProHub.exe'));
    return exe.existsSync() ? exe.path : null;
  }

  @override
  Future<bool> start(String exe, [List<String> args = const []]) async {
    try {
      await Process.start(exe, args, workingDirectory: p.dirname(exe), mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }
}
