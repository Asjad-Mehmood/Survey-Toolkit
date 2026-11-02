// Running in the background (T5): the Toolkit's icon in the Windows notification area (the tray),
// its notifications, and starting with Windows.
//
// The tray icon, its menu (Open, Check for updates now, Quit) and the notifications are the
// Windows program's own (windows/runner/tray.cpp), reached through the "survey_toolkit/tray"
// channel. Notifications are the tray icon's, so Windows 10 and 11 show them as ordinary
// notifications with nothing else to register.
//
// "Start with Windows" is a value under HKCU\...\Run that starts the Toolkit with --tray: no
// window, just the icon, checking for updates. With it on, closing the window keeps the Toolkit
// in the tray; with it off (the default) closing the window quits as before. The Toolkit's
// uninstaller removes the value.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../toolkit/detect.dart';

abstract class Tray {
  /// Shows the icon (the program, not the command line used by the Windows test)
  Future<void> start();

  /// Closing the window hides it in the tray instead of quitting
  Future<void> keepInTray(bool on);

  Future<void> notify(String title, String text);

  /// Takes the icon away before the Toolkit quits by itself (the self-update)
  Future<void> remove();

  /// The tray menu's "Check for updates now"
  set onCheckNow(void Function()? f);
}

class WindowsTray implements Tray {
  static const _channel = MethodChannel('survey_toolkit/tray');
  void Function()? _check;

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // not the Windows program (tests)
    } on PlatformException {
      // the icon couldn't be shown: the Toolkit works without it
    }
  }

  @override
  Future<void> start() => _call('start');

  @override
  Future<void> keepInTray(bool on) => _call('keepInTray', on);

  @override
  Future<void> notify(String title, String text) => _call('notify', {'title': title, 'text': text});

  @override
  Future<void> remove() => _call('remove');

  @override
  set onCheckNow(void Function()? f) {
    _check = f;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'checkNow') _check?.call();
    });
  }
}

/// No tray (tests, and anything that isn't Windows)
class NoTray implements Tray {
  @override
  Future<void> start() async {}
  @override
  Future<void> keepInTray(bool on) async {}
  @override
  Future<void> notify(String title, String text) async {}
  @override
  Future<void> remove() async {}
  @override
  set onCheckNow(void Function()? f) {}
}

abstract class StartWithWindows {
  Future<bool> isOn();

  /// true when Windows took it
  Future<bool> set(bool on);
}

class WindowsStartup implements StartWithWindows {
  WindowsStartup({String? exe, RegistryReader? registry})
    : exe = exe ?? Platform.resolvedExecutable,
      _reg = registry ?? readRegistry;

  static const runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const valueName = 'SurveyToolkit';
  final String exe;
  final RegistryReader _reg;

  /// What Windows runs at sign-in
  String get command => startCommand(exe);

  @override
  Future<bool> isOn() async => (await _reg(runKey))?.containsKey(valueName) ?? false;

  @override
  Future<bool> set(bool on) async {
    try {
      final r = await Process.run(
        'reg',
        on
            ? ['add', runKey, '/v', valueName, '/t', 'REG_SZ', '/d', command, '/f']
            : ['delete', runKey, '/v', valueName, '/f'],
      );
      // deleting a value that isn't there is fine too
      return r.exitCode == 0 || (!on && !await isOn());
    } catch (_) {
      return false;
    }
  }
}

/// The Run value: the program, quoted, started in the tray
String startCommand(String exe) => '"$exe" --tray';

/// Was the program started by Windows at sign-in (in the tray, no window)?
bool startedInTray(List<String> args) => args.contains('--tray');

/// The switch on the Tools page, and what it controls
class Background extends ChangeNotifier {
  Background({required this.tray, required this.startup});

  final Tray tray;
  final StartWithWindows startup;

  bool _on = false;
  bool get on => _on;

  /// Windows has been asked once
  bool known = false;
  bool saving = false;
  String? problem;

  /// On start: is it on? Then the Run value is written again (the Toolkit may have moved) and the
  /// window kept in the tray when closed.
  Future<void> load() async {
    try {
      _on = await startup.isOn();
      if (_on) await startup.set(true);
    } catch (_) {
      _on = false;
    }
    known = true;
    await tray.keepInTray(_on);
    notifyListeners();
  }

  Future<bool> setOn(bool on) async {
    saving = true;
    problem = null;
    notifyListeners();
    final ok = await startup.set(on);
    if (ok) {
      _on = on;
      await tray.keepInTray(on);
    } else {
      problem = 'Windows didn\'t take the change. Try again.';
    }
    saving = false;
    notifyListeners();
    return ok;
  }
}
