// The Toolkit: sign in first, then the beta list, then the Tools page.
import 'dart:async';

import 'package:flutter/material.dart';

import 'account/account.dart';
import 'brand.dart';
import 'screens/beta_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/tools_screen.dart';
import 'toolkit/toolkit_model.dart';
import 'ui/settings.dart';
import 'ui/theme.dart';
import 'update/updater.dart';

class ToolkitApp extends StatelessWidget {
  const ToolkitApp({
    super.key,
    required this.account,
    required this.model,
    required this.settings,
    this.checkUpdates = true,
  });
  final Account account;
  final ToolkitModel model;
  final AppSettings settings;

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
      home: _Gate(account: account, model: model, settings: settings, checkUpdates: checkUpdates),
    ),
  );
}

class _Gate extends StatefulWidget {
  const _Gate({required this.account, required this.model, required this.settings, required this.checkUpdates});
  final Account account;
  final ToolkitModel model;
  final AppSettings settings;
  final bool checkUpdates;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _started = false;
  late bool _updateChecked = !widget.checkUpdates;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    unawaited(widget.account.restore());
    // back at the front after a while: look again (a tool may have been installed meanwhile)
    _life = AppLifecycleListener(
      onResume: () {
        final at = widget.model.checkedAt;
        if (_started && (at == null || DateTime.now().difference(at) > const Duration(minutes: 10))) {
          unawaited(widget.model.refresh());
        }
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(checkForUpdate(context));
      });
    }
    if (a.checking || !a.signedIn) {
      _started = false;
      return SignInScreen(account: a, settings: widget.settings);
    }
    if (a.beta != BetaAccess.tester) {
      _started = false;
      return BetaScreen(account: a);
    }
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(widget.model.refresh()));
    }
    return ToolsScreen(model: widget.model, account: a, settings: widget.settings);
  }
}
