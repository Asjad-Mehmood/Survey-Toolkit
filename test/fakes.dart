// A fake exceltokml.com and a PC with some tools, shared by the app tests and the screenshots.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:survey_toolkit/src/account/account.dart';
import 'package:survey_toolkit/src/account/api.dart';
import 'package:survey_toolkit/src/app.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/feed.dart';
import 'package:survey_toolkit/src/toolkit/installer.dart';
import 'package:survey_toolkit/src/toolkit/toolkit_model.dart';
import 'package:survey_toolkit/src/ui/settings.dart';
import 'package:survey_toolkit/src/update/background.dart';
import 'package:survey_toolkit/src/workspace/app_view.dart';
import 'package:survey_toolkit/src/workspace/apps.dart';

/// A fake exceltokml.com
class FakeSite {
  bool online = true;
  bool tester = true;
  bool tokenGood = true;
  final reports = <Map<String, Object?>>[];
  final handoffs = <String>[];
  bool handoffWorks = true;
  String feed = File('test/fixtures/feed.json').readAsStringSync();

  late final client = MockClient((req) async {
    if (!online) throw http.ClientException('offline');
    final path = req.url.path;
    final authed = req.headers['Authorization'] == 'Bearer tok' && tokenGood;
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    switch (path) {
      case '/api/auth/me':
        return authed ? json({'user': user}) : json({'error': 'Sign in'}, 401);
      case '/api/auth/login':
        final b = jsonDecode(req.body) as Map;
        return b['password'] == 'right'
            ? json({'user': user, 'token': 'tok'})
            : json({'error': 'Wrong email or password.'}, 401);
      case '/api/toolkit/me':
        if (!authed) return json({'error': 'Sign in'}, 401);
        return json({
          'success': true,
          'tester': tester,
          'admin': false,
          if (!tester) 'message': 'The Survey Toolkit isn\'t open to this account just now. Please try again later.',
        });
      case '/api/toolkit/feed':
        return http.Response(feed, 200, headers: {'content-type': 'application/json'});
      case '/api/toolkit/handoff':
        if (!authed) return json({'error': 'Sign in'}, 401);
        if (!handoffWorks) return json({'error': 'Couldn\'t start the sign-in.'}, 500);
        handoffs.add((jsonDecode(req.body) as Map)['next'] as String);
        return json({'success': true, 'url': 'https://www.exceltokml.com/api/toolkit/handoff?code=${'c' * 64}'});
      case '/api/toolkit/event':
        if (!authed) return json({'error': 'Sign in'}, 401);
        reports.add(jsonDecode(req.body) as Map<String, Object?>);
        return json({'success': true});
      case '/api/auth/logout':
        return json({'success': true});
    }
    return json({'error': 'not found'}, 404);
  });

  static const user = {'id': 'u1', 'email': 'tester@example.com', 'name': 'Test Surveyor'};
}

class FakeDetector implements Detector {
  FakeDetector(this.found, {this.autocad = true});
  final Map<String, Installed> found;
  final bool autocad;
  @override
  Future<Installed> find(FeedTool tool) async => found[tool.id] ?? Installed.none;
  @override
  Future<bool> hasAutocad() async => autocad;
}

/// Excel to KML one version behind, Slope Calculator up to date with a program to open, the
/// others not installed, no AutoCAD
FakeDetector typicalPc() => FakeDetector({
  'excel-to-kml': const Installed(version: '4.3.1', folder: r'C:\X', program: r'C:\X\ExcelToKML.exe'),
  'slope': const Installed(version: '1.0.3', folder: r'C:\S', program: r'C:\S\SlopeCalculator.exe'),
}, autocad: false);

/// Installs nothing: answers what the test sets, when the test says (via [gate])
class FakeInstaller extends ToolInstaller {
  FakeInstaller({Detector? detector})
    : super(
        places: Places(localAppData: 'L', appData: 'R'),
        detector: detector ?? FakeDetector(const {}),
      );

  JobResult next = const JobResult.done('Done.');
  Completer<void>? gate;
  final calls = <String>[];

  @override
  Future<JobResult> install(FeedTool t, {Installed? current, void Function(JobProgress)? onProgress}) async {
    calls.add('install ${t.id}');
    onProgress?.call(const JobProgress('Downloading', 0.42));
    await gate?.future;
    return next;
  }

  @override
  Future<JobResult> uninstall(FeedTool t, Installed current) async {
    calls.add('uninstall ${t.id}');
    await gate?.future;
    return next;
  }

  @override
  String? cannotUninstall(FeedTool t, Installed i) => i.found ? null : 'not installed';

  @override
  void log(String line) {}
}

/// Stands in for WebView2: shows the address it was opened at
class FakeView implements AppViewHandle {
  FakeView(this.app, Future<String> Function() start) {
    start().then((u) {
      started = u;
      _state.value = AppViewState(loading: false, url: u);
    });
  }
  final WorkspaceApp app;
  String? started;
  bool forgot = false;
  bool disposed = false;
  final _state = ValueNotifier(const AppViewState());

  @override
  ValueListenable<AppViewState> get state => _state;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _state,
    builder: (context, s, _) => Center(child: Text('Showing ${s.url ?? '…'}')),
  );

  @override
  Future<void> back() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> forget() async => forgot = true;
  @override
  void dispose() => disposed = true;
}

class Harness {
  Harness({
    required this.site,
    required this.store,
    Detector? detector,
    ToolInstaller? installer,
    bool lookOnly = false,
  }) {
    background = Background(tray: tray, startup: startup);
    account = Account(Api(base: 'https://www.exceltokml.com', client: site.client), store);
    this.installer = lookOnly ? null : installer ?? FakeInstaller();
    model = ToolkitModel(account: account, store: store, detector: detector ?? typicalPc(), installer: this.installer);
    settings = AppSettings(store);
  }
  late final ToolInstaller? installer;

  /// The app windows opened, in order
  final views = <FakeView>[];
  AppViewHandle _view(WorkspaceApp app, Future<String> Function() start) {
    final v = FakeView(app, start);
    views.add(v);
    return v;
  }

  final FakeSite site;
  final Store store;
  late final Account account;
  late final ToolkitModel model;
  late final AppSettings settings;
  final tray = FakeTray();
  final startup = FakeStartup();
  late final Background background;

  // no self-update check: on Windows it would leave its timer running after the test
  Widget get app => ToolkitApp(
    account: account,
    model: model,
    settings: settings,
    checkUpdates: false,
    views: _view,
    background: background,
  );
}

/// A store as if this account signed in on this PC before
Store signedInStore({String beta = 'tester'}) {
  final s = Store.memory();
  s.writeJson('account', {'token': 'tok', 'user': FakeSite.user, 'beta': beta});
  return s;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// The tray icon: what it was asked to do
class FakeTray implements Tray {
  final notes = <String>[];
  bool? kept;
  void Function()? checkNow;
  bool removed = false;

  @override
  Future<void> start() async {}
  @override
  Future<void> keepInTray(bool on) async => kept = on;
  @override
  Future<void> notify(String title, String text) async => notes.add('$title: $text');
  @override
  Future<void> remove() async => removed = true;
  @override
  set onCheckNow(void Function()? f) => checkNow = f;
}

/// The Run value, in memory
class FakeStartup implements StartWithWindows {
  bool on = false;
  bool works = true;
  final sets = <bool>[];

  @override
  Future<bool> isOn() async => on;
  @override
  Future<bool> set(bool v) async {
    sets.add(v);
    if (works) on = v;
    return works;
  }
}
