// For the Windows test (tool/windows_check.ps1), no window needed beyond a flash:
//   SurveyToolkit.exe --detect=<out.json>
//       looks for the five tools on this PC (the built-in list: no website, no sign-in), writes
//       what it found and closes;
//   SurveyToolkit.exe --install=<tool id> --feed=<feed.json> --result=<out.json>
//   SurveyToolkit.exe --uninstall=<tool id> --feed=<feed.json> --result=<out.json>
//       installs, updates or removes one tool exactly as its card's button does, with the
//       download, SHA-256 and how to install it from <feed.json> (the website's feed format),
//       writes the result and closes.
//   SurveyToolkit.exe --auto-update --feed=<feed.json> --result=<out.json> [--ask=<id>,<id>]
//       the automatic update (T5) once, as the Toolkit does every 4 hours, with the tools in --ask
//       set to Ask me: updates what is due, writes what was updated and what waits, and closes;
//   SurveyToolkit.exe --start-with-windows=on|off --result=<out.json>
//       the Updates section's switch: writes or removes the Run value.
//
// For the programs the Toolkit installs, opened some other way (a desktop shortcut, the Start
// menu) before they are signed in:
//   SurveyToolkit.exe --app-code=<tool id> --result=<out.json>
//       a one-use sign-in code for the Toolkit's account, for that program alone, written as
//       {"code": "…"} ({"code": null} when the Toolkit isn't signed in or the website can't give
//       one). No window, also while the Toolkit is open.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'account/account.dart';
import 'account/api.dart';
import 'brand.dart';
import 'state/store.dart';
import 'toolkit/detect.dart';
import 'toolkit/feed.dart';
import 'toolkit/installer.dart';
import 'toolkit/toolkit_model.dart' show signsInFromToolkit;
import 'update/background.dart';
import 'update/update_prefs.dart';

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
    detectTarget(args) != null ||
    argValue(args, 'install') != null ||
    argValue(args, 'uninstall') != null ||
    args.contains('--auto-update') ||
    argValue(args, 'start-with-windows') != null ||
    argValue(args, 'app-code') != null;

/// A one-use sign-in code for [app] from the Toolkit's own account on this PC (its sign-in)
Future<String?> toolkitAppCode(String app) async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  return Account(Api(base: apiBase, client: http.Client()), store).appCode(app);
}

Future<Map<String, Object?>> detectAll(Detector detector) async => {
  'toolkitVersion': appVersion,
  'autocad': await detector.hasAutocad(),
  'tools': {for (final t in builtInTools) t.id: (await detector.find(t)).toJson()},
};

Future<void> _write(String target, Map<String, Object?> j) =>
    File(target).writeAsString(const JsonEncoder.withIndent('  ').convert(j), flush: true);

/// Runs the command line; the process's exit code
Future<int> runCommandLine(
  List<String> args, {
  Places? places,
  Detector? detector,
  ToolInstaller? installer,
  StartWithWindows? startup,
  Future<String?> Function(String app) appCode = toolkitAppCode,
}) async {
  final codeFor = argValue(args, 'app-code');
  if (codeFor != null) {
    final out = argValue(args, 'result');
    // only for the programs that sign in, and only to a file they asked for
    final code = signsInFromToolkit.contains(codeFor) ? await appCode(codeFor) : null;
    if (out != null) await _write(out, {'code': code});
    return code == null ? 1 : 0;
  }
  places ??= Places.windows();
  detector ??= WindowsDetector(places: places);
  final detect = detectTarget(args);
  if (detect != null) {
    await _write(detect, await detectAll(detector));
    return 0;
  }
  final result = argValue(args, 'result');
  final start = argValue(args, 'start-with-windows');
  if (start != null) {
    startup ??= WindowsStartup();
    final ok = (start == 'on' || start == 'off') && await startup.set(start == 'on');
    if (result != null) await _write(result, {'ok': ok, 'on': await startup.isOn()});
    return ok ? 0 : 1;
  }
  if (args.contains('--auto-update')) {
    return autoUpdateOnce(
      args,
      detector: detector,
      installer: installer ?? ToolInstaller(places: places, detector: detector),
    );
  }
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

/// --auto-update: the automatic update once, with the same plan and installer as the Toolkit's
Future<int> autoUpdateOnce(List<String> args, {required Detector detector, required ToolInstaller installer}) async {
  final result = argValue(args, 'result');
  final feedFile = argValue(args, 'feed');
  final ask = {...?argValue(args, 'ask')?.split(',')};
  Feed? feed;
  try {
    if (feedFile != null) feed = Feed.from(jsonDecode(await File(feedFile).readAsString()));
  } catch (_) {}
  if (feed == null) {
    if (result != null) await _write(result, {'ok': false, 'message': 'The feed file could not be read.'});
    return 1;
  }
  final found = {for (final t in feed.tools) t.id: await detector.find(t)};
  final plan = planUpdates(
    tools: feed.tools,
    installed: (id) => found[id],
    modeOf: (id) => ask.contains(id) ? UpdateMode.ask : UpdateMode.automatic,
    autocad: await detector.hasAutocad(),
  );
  final updated = <String, String?>{};
  final failed = <String, String>{};
  for (final t in plan.now) {
    final current = found[t.id];
    final r = await installer.install(t, current: current != null && current.found ? current : null);
    if (r.ok) {
      updated[t.id] = r.version;
    } else {
      failed[t.id] = r.message;
    }
  }
  if (result != null) {
    await _write(result, {
      'ok': failed.isEmpty,
      'updated': updated,
      'waiting': {for (final e in plan.waiting.entries) e.key: e.value.name},
      'failed': failed,
      'notification': updatedText([
        for (final t in feed.tools)
          if (updated.containsKey(t.id)) (t.name, updated[t.id] ?? t.version ?? ''),
      ]),
    });
  }
  return failed.isEmpty ? 0 : 1;
}
