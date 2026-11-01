// The rules under the Tools page: versions, the feed, finding tools, statuses and the self-update.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/cli.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/feed.dart';
import 'package:survey_toolkit/src/toolkit/status.dart';
import 'package:survey_toolkit/src/toolkit/version.dart';
import 'package:survey_toolkit/src/update/update_check.dart';

Map<String, Object?> fixtureFeed() =>
    jsonDecode(File('test/fixtures/feed.json').readAsStringSync()) as Map<String, Object?>;

void main() {
  group('versions', () {
    test('compare as the products write them', () {
      expect(compareVersions('4.4.0', '4.3.1'), 1);
      expect(compareVersions('3.4', '3.4.0'), 0);
      expect(compareVersions('1.0.10', '1.0.9'), 1);
      expect(compareVersions('v2.1.0', '2.1.0'), 0);
      expect(compareVersions('6.1', '6.2'), -1);
      expect(isNewer('1.0.3', '1.0.2'), isTrue);
      expect(isNewer('1.0.2', '1.0.2'), isFalse);
    });
    test('only version-looking text is taken as a version', () {
      expect(looksLikeVersion('4.4.0'), isTrue);
      expect(looksLikeVersion('3.4'), isTrue);
      expect(looksLikeVersion('1.0.0.1'), isTrue);
      expect(looksLikeVersion(''), isFalse);
      expect(looksLikeVersion('4.4.0; rm -rf'), isFalse);
      expect(looksLikeVersion('latest'), isFalse);
    });
  });

  group('feed', () {
    test('reads the website feed: five tools with versions, downloads and how to find them', () {
      final f = Feed.from(fixtureFeed())!;
      expect(f.tools.map((t) => t.id), ['excel-to-kml', 'roadpro', 'traverse', 'folder-manager', 'slope']);
      final excel = f.tools.first;
      expect(excel.version, '4.4.0');
      expect(excel.download!.sha256, hasLength(64));
      expect(excel.install.registryKey, 'ExcelToKMLPro');
      expect(excel.install.exe, ['ExcelToKML.exe', 'ExcelToKMLPro.exe']);
      expect(excel.install.opensAfterSilentInstall, isTrue);
      final pfm = f.tools[3];
      expect(pfm.install.kind, 'zip');
      expect(pfm.install.keep, ['Project_Folder_Manager_config.txt']);
      expect(f.tools.last.problems.single, contains('latest.json'));
    });

    test('a download from anywhere but the website or GitHub, or without HTTPS, is dropped', () {
      final j = fixtureFeed();
      final tools = j['tools']! as List;
      ((tools[0] as Map)['download'] as Map)['url'] = 'https://evil.example.com/ExcelToKML-Setup.exe';
      ((tools[2] as Map)['download'] as Map)['url'] = 'http://github.com/x.exe';
      ((tools[4] as Map)['download'] as Map)['sha256'] = 'not-a-hash';
      final f = Feed.from(j)!;
      expect(f.tools[0].download, isNull);
      expect(f.tools[2].download, isNull);
      expect(f.tools[4].download, isNull);
      expect(f.tools[1].download, isNotNull);
    });

    test('file names with paths or odd characters are dropped', () {
      final j = fixtureFeed();
      (((j['tools']! as List)[0] as Map)['install'] as Map)['exe'] = ['..\\..\\Windows\\evil.exe', 'ExcelToKML.exe'];
      expect(Feed.from(j)!.tools[0].install.exe, ['ExcelToKML.exe']);
    });

    test('a feed of another format, or empty, is not read', () {
      expect(Feed.from({'schema': 2, 'tools': []}), isNull);
      expect(Feed.from({'schema': 1, 'tools': []}), isNull);
      expect(Feed.from('nonsense'), isNull);
    });

    test('a version the website couldn\'t read is null, not a guess', () {
      final j = fixtureFeed();
      ((j['tools']! as List)[0] as Map)['version'] = null;
      expect(Feed.from(j)!.tools[0].version, isNull);
    });

    test('the built-in list knows all five tools, matching the feed', () {
      final f = Feed.from(fixtureFeed())!;
      expect(builtInTools.map((t) => t.id), f.tools.map((t) => t.id));
      for (var i = 0; i < builtInTools.length; i++) {
        expect(builtInTools[i].install.kind, f.tools[i].install.kind);
        expect(builtInTools[i].install.registryKey, f.tools[i].install.registryKey);
        expect(builtInTools[i].install.exe, f.tools[i].install.exe);
      }
    });
  });

  group('finding tools on a PC', () {
    test('reads reg.exe output', () {
      const out =
          '\r\nHKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ExcelToKMLPro\r\n'
          '    DisplayName    REG_SZ    Excel to KML\r\n'
          '    DisplayVersion    REG_SZ    4.4.0\r\n'
          '    DisplayIcon    REG_SZ    C:\\Users\\Asjad Mehmood\\AppData\\Local\\ExcelToKMLPro\\icon.ico\r\n'
          '    UninstallString    REG_SZ    C:\\Users\\Asjad Mehmood\\AppData\\Local\\ExcelToKMLPro\\Uninstall.exe\r\n'
          '    NoModify    REG_DWORD    0x1\r\n\r\n';
      final v = parseRegQuery(out);
      expect(v['DisplayVersion'], '4.4.0');
      expect(v['DisplayName'], 'Excel to KML');
      expect(v['UninstallString'], r'C:\Users\Asjad Mehmood\AppData\Local\ExcelToKMLPro\Uninstall.exe');
      expect(v['NoModify'], '0x1');
    });

    test('takes the quotes off a path', () {
      expect(unquote('"C:\\Program Files\\X"'), r'C:\Program Files\X');
      expect(unquote(r'C:\X'), r'C:\X');
    });

    test('RoadPro\'s version from the top of RoadPro.lsp', () {
      const head =
          ';;;============================================================================\n'
          ';;;  RoadPro.lsp  -  Professional Road Builder for AutoCAD\n'
          ';;;  Version : 3.4                                   Date : 23-Oct-2026\n';
      expect(lspVersion(head), '3.4');
      expect(lspVersion('(defun c:rdp ())'), isNull);
    });

    test('Project Folder Manager\'s version from its .hta', () {
      const hta =
          '<div class="t2">Project Folder Manager &nbsp;&middot;&nbsp; Survey &amp; Engineering Document Control</div>\n'
          '/*\n   PROJECT FOLDER MANAGER  v6.2\n   v6.2 :  renamed\n*/';
      expect(htaVersion(hta), '6.2');
      expect(htaVersion('<html></html>'), isNull);
    });

    test('--detect writes what was found for the Windows test', () async {
      expect(detectTarget(['--detect=C:\\t\\out.json']), r'C:\t\out.json');
      expect(detectTarget(['--detect=']), isNull);
      expect(detectTarget([]), isNull);
      final j = await detectAll(_Fixed({'slope': const Installed(version: '1.0.3', folder: r'C:\S')}));
      expect((j['tools']! as Map)['slope'], {'version': '1.0.3', 'folder': r'C:\S'});
      expect((j['tools']! as Map)['roadpro'], {'version': null});
      expect(j['autocad'], isFalse);
    });
  });

  group('status', () {
    final f = Feed.from(fixtureFeed())!;
    final excel = f.tools[0], roadpro = f.tools[1];

    test('from the installed and the latest version', () {
      expect(stateOf(excel, null), ToolState.checking);
      expect(stateOf(excel, Installed.none), ToolState.notInstalled);
      expect(stateOf(excel, const Installed(version: '4.4.0')), ToolState.upToDate);
      expect(stateOf(excel, const Installed(version: '4.3.1')), ToolState.updateAvailable);
      expect(stateOf(excel, const Installed(version: '4.5.0')), ToolState.upToDate);
    });

    test('installed but the latest can\'t be read: not called up to date', () {
      final j = fixtureFeed();
      ((j['tools']! as List)[0] as Map)['version'] = null;
      final noVersion = Feed.from(j)!.tools[0];
      expect(stateOf(noVersion, const Installed(version: '4.4.0')), ToolState.unknown);
    });

    test('RoadPro without AutoCAD', () {
      expect(stateOf(roadpro, Installed.none, autocad: false), ToolState.needsAutocad);
      expect(stateOf(roadpro, Installed.none), ToolState.notInstalled);
      expect(stateOf(roadpro, const Installed(version: '3.3'), autocad: false), ToolState.updateAvailable);
    });
  });

  group('self-update', () {
    Map<String, Object?> rel(String tag, {bool draft = false, bool pre = true, List<String>? names}) => {
      'tag_name': tag,
      'draft': draft,
      'prerelease': pre,
      'assets': [
        for (final n in names ?? ['SurveyToolkit-Setup.exe', 'latest.json'])
          {
            'name': n,
            'browser_download_url': 'https://github.com/Asjad-Mehmood/Survey-Toolkit/releases/download/$tag/$n',
          },
      ],
    };

    test('takes the newest pre-release with both files, never a draft', () {
      final r = newestRelease([
        rel('v0.3.0', draft: true),
        rel('v0.2.1', names: ['SurveyToolkit-Setup.exe']),
        rel('v0.2.0'),
        rel('v0.1.0'),
      ])!;
      expect(r.tag, 'v0.2.0');
      expect(r.manifestUrl, endsWith('/v0.2.0/latest.json'));
      expect(r.installerUrl, endsWith('/v0.2.0/SurveyToolkit-Setup.exe'));
    });

    test('ignores files that aren\'t on github.com', () {
      final bad = rel('v0.2.0');
      ((bad['assets']! as List).first as Map)['browser_download_url'] =
          'https://evil.example.com/SurveyToolkit-Setup.exe';
      expect(newestRelease([bad]), isNull);
      expect(newestRelease('nonsense'), isNull);
    });

    test('latest.json and the version check', () {
      final h = 'a' * 64;
      final info = UpdateInfo.parse('{"version":"0.2.0","sha256":"$h"}')!;
      expect(offersUpdate(info, '0.1.0'), isTrue);
      expect(offersUpdate(info, '0.2.0'), isFalse);
      expect(offersUpdate(null, '0.1.0'), isFalse);
      expect(UpdateInfo.parse('{"version":"0.2","sha256":"$h"}'), isNull);
      expect(UpdateInfo.parse('nonsense'), isNull);
      expect(
        sha256Matches(utf8.encode('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
        isTrue,
      );
    });
  });
}

class _Fixed implements Detector {
  _Fixed(this.found);
  final Map<String, Installed> found;
  @override
  Future<Installed> find(FeedTool tool) async => found[tool.id] ?? Installed.none;
  @override
  Future<bool> hasAutocad() async => false;
}
