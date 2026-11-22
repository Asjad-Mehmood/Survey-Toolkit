// SurveyToolkit.exe --app-code=<id> --result=<file>: a program opened from a shortcut asks the
// Toolkit for a one-use sign-in code for the Toolkit's account.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/cli.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('appcode'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, Object?)> run(List<String> args, Future<String?> Function(String) appCode) async {
    final out = '${dir.path}/out.json';
    final exit = await runCommandLine([...args, '--result=$out'], appCode: appCode);
    final f = File(out);
    return (exit, f.existsSync() ? (jsonDecode(f.readAsStringSync()) as Map)['code'] : 'no file');
  }

  test('a program that signs in gets a code for the Toolkit\'s account', () async {
    final asked = <String>[];
    expect(isCommandLine(['--app-code=slope']), isTrue);
    final r = await run(['--app-code=slope'], (a) async {
      asked.add(a);
      return 'a' * 64;
    });
    expect(r, (0, 'a' * 64));
    expect(asked, ['slope']);
  });

  test('not signed in (or the website can\'t give one): no code, and the program shows its sign-in', () async {
    expect(await run(['--app-code=auto-draft'], (_) async => null), (1, null));
  });

  test('only the programs that sign in: nothing is asked for anything else', () async {
    var asked = false;
    final r = await run(['--app-code=roadpro'], (_) async {
      asked = true;
      return 'a' * 64;
    });
    expect(r, (1, null));
    expect(asked, isFalse);
  });
}
