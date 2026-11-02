// The Windows program and its installer agree with the code (T7): the uninstaller removes every
// place the Toolkit writes to, and the names the runner and the installer use are the app's.
// A mismatch here would leave files, a sign-in or a start-up entry behind on a tester's PC.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:survey_toolkit/src/brand.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/update/background.dart';

void main() {
  final nsi = File('installer/installer.nsi').readAsStringSync();
  final uninstall = nsi.substring(nsi.indexOf('Section "Uninstall"'));
  final rc = File('windows/runner/Runner.rc').readAsStringSync();
  final mainCpp = File('windows/runner/main.cpp').readAsStringSync();
  String rcValue(String name) => RegExp('VALUE "$name", "([^"]*)"').firstMatch(rc)!.group(1)!;
  final places = Places(localAppData: r'C:\L', appData: r'C:\R');
  // Places joins with this system's separator; the installer is Windows'
  String nsisPath(String path, String root, String variable) =>
      '$variable${path.substring(root.length)}'.replaceAll('/', r'\');

  test('the uninstaller removes what the Toolkit writes in %LOCALAPPDATA%\\Survey Toolkit', () {
    for (final path in [p.join(places.toolkit, 'WebView'), places.downloads]) {
      expect(uninstall, contains('RMDir /r "${nsisPath(path, r'C:\L', r'$LOCALAPPDATA')}"'));
    }
    expect(uninstall, contains('Delete "${nsisPath(places.log, r'C:\L', r'$LOCALAPPDATA')}"'));
    expect(uninstall, contains('Delete "${nsisPath('${places.log}.1', r'C:\L', r'$LOCALAPPDATA')}"'));
    // only when empty: the user's Project Folder Manager settings stay
    expect(uninstall, contains('RMDir "${nsisPath(places.toolkit, r'C:\L', r'$LOCALAPPDATA')}"'));
    expect(uninstall, isNot(contains('RMDir /r "${nsisPath(places.toolkit, r'C:\L', r'$LOCALAPPDATA')}"')));
  });

  test('the uninstaller removes the settings and sign-in, where Flutter keeps them', () {
    // shared_preferences on Windows: %APPDATA%\<CompanyName>\<ProductName>
    expect(rcValue('ProductName'), appName);
    expect(uninstall, contains('RMDir /r "\$APPDATA\\${rcValue('CompanyName')}\\${rcValue('ProductName')}"'));
  });

  test('the uninstaller removes Start with Windows, by the name the Toolkit writes', () {
    expect(WindowsStartup.runKey, r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run');
    expect(
      uninstall,
      contains('DeleteRegValue HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Run" "${WindowsStartup.valueName}"'),
    );
  });

  test('one window: the runner looks for the window by the app\'s name, and the exe is the installer\'s', () {
    expect(mainCpp, contains('FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"$appName")'));
    expect(mainCpp, contains('window.Create(L"$appName"'));
    expect(nsi, contains('!define EXE "SurveyToolkit.exe"'));
    expect(File('windows/CMakeLists.txt').readAsStringSync(), contains('set(BINARY_NAME "SurveyToolkit")'));
  });
}
