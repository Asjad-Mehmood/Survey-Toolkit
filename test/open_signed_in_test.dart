// Opening a program from the Toolkit signs it in to the same account: it is given a one-use code.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/account/account.dart';
import 'package:survey_toolkit/src/account/api.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/toolkit_model.dart';

import 'fakes.dart';

void main() {
  late Directory dir;
  late FakeSite site;
  late List<List<String>> started;

  setUp(() => dir = Directory.systemTemp.createTempSync('open'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ToolkitModel> pc({required Store store, required String id}) async {
    site = FakeSite();
    started = [];
    final account = Account(Api(base: 'https://www.surveyxdigital.com', client: site.client), store);
    await account.restore();
    final exe = File('${dir.path}/$id.exe')..writeAsStringSync('');
    final model = ToolkitModel(
      account: account,
      store: store,
      detector: FakeDetector({id: Installed(version: '9.9.9', folder: dir.path, program: exe.path)}),
      start: (program, args, folder) async => started.add(args),
    );
    await model.refresh();
    return model;
  }

  test('a program with a sign-in is given a one-use code for the Toolkit\'s account', () async {
    final model = await pc(store: signedInStore(), id: 'slope');
    expect(await model.open(model.tools.firstWhere((t) => t.id == 'slope')), isTrue);
    expect(site.appCodes, ['slope']);
    expect(started, [
      ['--signin-code=${'a' * 64}'],
    ]);
  });

  test('when the website can\'t give a code, the program still opens, and asks for a sign-in', () async {
    final model = await pc(store: signedInStore(), id: 'excel-to-kml');
    site.appCodeWorks = false;
    expect(await model.open(model.tools.firstWhere((t) => t.id == 'excel-to-kml')), isTrue);
    expect(started, [<String>[]]);
  });

  test('a program without a sign-in gets no code', () async {
    final model = await pc(store: signedInStore(), id: 'roadpro');
    final t = model.tools.firstWhere((t) => t.id == 'roadpro');
    expect(await model.open(t), isTrue);
    expect(site.appCodes, isEmpty);
    expect(started, [<String>[]]);
  });
}
