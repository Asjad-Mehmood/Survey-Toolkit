// A fake exceltokml.com and a PC with some tools, shared by the app tests and the screenshots.
import 'dart:convert';
import 'dart:io';

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
import 'package:survey_toolkit/src/toolkit/toolkit_model.dart';
import 'package:survey_toolkit/src/ui/settings.dart';

/// A fake exceltokml.com
class FakeSite {
  bool online = true;
  bool tester = true;
  bool tokenGood = true;
  final reports = <Map<String, Object?>>[];
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
          if (!tester) 'message': 'The Survey Toolkit beta is closed. It opens to everyone when the test is over.',
        });
      case '/api/toolkit/feed':
        return http.Response(feed, 200, headers: {'content-type': 'application/json'});
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

class Harness {
  Harness({required this.site, required this.store, Detector? detector}) {
    account = Account(Api(base: 'https://www.exceltokml.com', client: site.client), store);
    model = ToolkitModel(account: account, store: store, detector: detector ?? typicalPc());
    settings = AppSettings(store);
  }
  final FakeSite site;
  final Store store;
  late final Account account;
  late final ToolkitModel model;
  late final AppSettings settings;

  // no self-update check: on Windows it would leave its timer running after the test
  Widget get app => ToolkitApp(account: account, model: model, settings: settings, checkUpdates: false);
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
