// For the Windows test (tool/windows_check.ps1): `SurveyToolkit.exe --detect=<file>` looks for the
// five tools on this PC, as the Tools page does, writes what it found to <file> as JSON and closes.
// It uses the built-in tool list, so it needs neither the website nor a sign-in.
import 'dart:convert';
import 'dart:io';

import 'brand.dart';
import 'toolkit/detect.dart';
import 'toolkit/feed.dart';

/// The file to write, when the program was started with `--detect=<file>`
String? detectTarget(List<String> args) {
  for (final a in args) {
    if (a.startsWith('--detect=') && a.length > '--detect='.length) return a.substring('--detect='.length);
  }
  return null;
}

Future<Map<String, Object?>> detectAll(Detector detector) async => {
  'toolkitVersion': appVersion,
  'autocad': await detector.hasAutocad(),
  'tools': {for (final t in builtInTools) t.id: (await detector.find(t)).toJson()},
};

Future<void> runDetect(String target) async {
  final result = await detectAll(WindowsDetector());
  await File(target).writeAsString(const JsonEncoder.withIndent('  ').convert(result), flush: true);
}
