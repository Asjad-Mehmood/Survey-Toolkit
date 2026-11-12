// The Toolkit: sign in first, then the beta list, then the workspace (the Tools page and the web
// apps). While a tester is signed in, the automatic updates run (lib/src/update/auto_update.dart).
import 'dart:async';

import 'package:flutter/material.dart';

import 'account/account.dart';
import 'brand.dart';
import 'roadpro/roadpro_pc.dart';
import 'screens/beta_screen.dart';
import 'screens/sign_in_screen.dart';
import 'toolkit/toolkit_model.dart';
import 'ui/settings.dart';
import 'ui/theme.dart';
import 'update/auto_update.dart';
import 'update/background.dart';
import 'update/updater.dart';
import 'workspace/app_view.dart';
import 'workspace/apps.dart';
import 'workspace/workspace_shell.dart';

class ToolkitApp extends StatelessWidget {
  const ToolkitApp({
    super.key,
    required this.account,
    required this.model,
    required this.settings,
    this.checkUpdates = true,
    this.views = webView2Factory,
    this.native = folderManagerView,
    this.roadproPc,
    this.background,
  });
  final Account account;
  final ToolkitModel model;
  final AppSettings settings;

  /// The tray and Start with Windows (none in tests unless given)
  final Background? background;

  /// How the workspace shows a web app (WebView2; a stand-in in tests)
  final AppViewFactory views;

  /// How the workspace shows Project Folder Manager (the program; a stand-in in tests)
  final NativeViewFactory native;

  /// AutoCAD and RoadPro Hub on this PC, for the RoadPro page (Windows' unless given)
  final RoadProPc? roadproPc;

  /// Looks for a new Toolkit a few seconds after opening (off in tests)
  final bool checkUpdates;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([settings, account, model]),
    builder: (context, _) => MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: _Gate(
        account: account,
        model: model,
        settings: settings,
        checkUpdates: checkUpdates,
        views: views,
        native: native,
        roadproPc: roadproPc,
        background: background ?? Background(tray: NoTray(), startup: _NoStartup()),
      ),
    ),
  );
}

class _Gate extends StatefulWidget {
  const _Gate({
    required this.account,
    required this.model,
    required this.settings,
    required this.checkUpdates,
    required this.views,
    required this.native,
    required this.roadproPc,
    required this.background,
  });
  final Account account;
  final ToolkitModel model;
  final AppSettings settings;
  final bool checkUpdates;
  final AppViewFactory views;
  final NativeViewFactory native;
  final RoadProPc? roadproPc;
  final Background background;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _started = false;
  late bool _updateChecked = !widget.checkUpdates;
  late final AppLifecycleListener _life;
  late final AutoUpdater _auto = AutoUpdater(
    model: widget.model,
    background: widget.background,
    alsoCheck: widget.checkUpdates ? _checkSelf : null,
  );

  Future<void> _checkSelf() async {
    if (mounted) await checkForUpdate(context, tray: widget.background.tray, wait: Duration.zero);
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.account.restore());
    unawaited(widget.background.load());
    // back at the front after a while: look again (a tool may have been installed meanwhile)
    _life = AppLifecycleListener(
      onResume: () {
        final at = widget.model.checkedAt;
        if (_started && (at == null || DateTime.now().difference(at) > const Duration(minutes: 10))) {
          unawaited(_auto.check());
        }
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    _auto.dispose();
    super.dispose();
  }

  /// Signed out, or not on the beta list: no automatic updates
  void _stopped() {
    if (_started) _auto.stop();
    _started = false;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(checkForUpdate(context, tray: widget.background.tray));
      });
    }
    if (a.checking || !a.signedIn) {
      _stopped();
      return SignInScreen(account: a, settings: widget.settings);
    }
    if (a.beta != BetaAccess.tester) {
      _stopped();
      return BetaScreen(account: a);
    }
    if (!_started) {
      _started = true;
      // checks now, then every 4 hours
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _started) _auto.start();
      });
    }
    return WorkspaceShell(
      account: a,
      model: widget.model,
      settings: widget.settings,
      views: widget.views,
      native: widget.native,
      roadproPc: widget.roadproPc,
      auto: _auto,
    );
  }
}

class _NoStartup implements StartWithWindows {
  @override
  Future<bool> isOn() async => false;
  @override
  Future<bool> set(bool on) async => false;
}
