// For the Windows test (tool/windows_check.ps1), no window needed beyond a flash:
//   SurveyToolkit.exe --detect=<out.json>
//       looks for the five tools on this PC (the built-in list: no website, no sign-in), writes
//       what it found and closes;
//   SurveyToolkit.exe --install=<tool id> --feed=<feed.json> --result=<out.json>
//   SurveyToolkit.exe --uninstall=<tool id> --feed=<feed.json> --result=<out.json>
//       installs, updates or removes one tool exactly as its card's button does, with the
//       download, SHA-256 and how to install it from <feed.json> (the website's feed format),
//       writes the result and closes.
import 'dart:convert';
import 'dart:io';

import 'brand.dart';
import 'toolkit/detect.dart';
import 'toolkit/feed.dart';
import 'toolkit/installer.dart';

/// The value of `--name=value`, or null
String? argValue(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix) && a.length > prefix.length) return a.substring(prefix.length);
  }
  return null;
}

/// The file to write, when the program was started with `--detect=<file>`
String? detectTarget(List<String> args) => argValue(args, 'detect');

/// Started for the Windows test rather than as the program
bool isCommandLine(List<String> args) =>
    detectTarget(args) != null || argValue(args, 'install') != null || argValue(args, 'uninstall') != null;

Future<Map<String, Object?>> detectAll(Detector detector) async => {
  'toolkitVersion': appVersion,
  'autocad': await detector.hasAutocad(),
  'tools': {for (final t in builtInTools) t.id: (await detector.find(t)).toJson()},
};

Future<void> _write(String target, Map<String, Object?> j) =>
    File(target).writeAsString(const JsonEncoder.withIndent('  ').convert(j), flush: true);

/// Runs the command line; the process's exit code
Future<int> runCommandLine(List<String> args, {Places? places, Detector? detector, ToolInstaller? installer}) async {
  places ??= Places.windows();
  detector ??= WindowsDetector(places: places);
  final detect = detectTarget(args);
  if (detect != null) {
    await _write(detect, await detectAll(detector));
    return 0;
  }
  final result = argValue(args, 'result');
  final feedFile = argValue(args, 'feed');
  final id = argValue(args, 'install') ?? argValue(args, 'uninstall');
  Future<int> answer(bool ok, String message, [String? version, bool blocked = false]) async {
    if (result != null) {
      await _write(result, {'ok': ok, 'blocked': blocked, 'message': message, 'version': version});
    }
    return ok ? 0 : (blocked ? 3 : 1);
  }

  if (feedFile == null || id == null) {
    return answer(false, 'Use --install=<id> or --uninstall=<id> with --feed=<file>.');
  }
  Feed? feed;
  try {
    feed = Feed.from(jsonDecode(await File(feedFile).readAsString()));
  } catch (_) {}
  if (feed == null) return answer(false, 'The feed file could not be read.');
  final tool = feed.tools.where((t) => t.id == id).firstOrNull;
  if (tool == null) return answer(false, 'No tool "$id" in the feed.');
  installer ??= ToolInstaller(places: places, detector: detector);
  final current = await detector.find(tool);
  final r = argValue(args, 'install') != null
      ? await installer.install(tool, current: current.found ? current : null)
      : await installer.uninstall(tool, current);
  return answer(r.ok, r.message, r.version, r.blocked);
}
