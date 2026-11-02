// Installing, updating and removing (lib/src/toolkit/installer.dart) in a temporary folder, with
// a fake website, a fake registry and fake installers: every way a job can go.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:survey_toolkit/src/cli.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/feed.dart';
import 'package:survey_toolkit/src/toolkit/installer.dart';

List<int> zipOf(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(a);
}

String shaOf(List<int> b) => sha256.convert(b).toString();

const roadproUrl = 'https://www.exceltokml.com/roadpro/RoadPro.zip';
const pfmUrl = 'https://www.exceltokml.com/project-folder-manager/Project_Folder_Manager.zip';
const slopeUrl =
    'https://github.com/Asjad-Mehmood/Slope-calculator-/releases/download/v1.0.3/SlopeCalculator-Setup.exe';

List<int> roadproZip(String v) => zipOf({
  'RoadPro.lsp': ';;;====\n;;;  RoadPro.lsp\n;;;  Version : $v      Date : 1-Nov-2026\n(defun c:rdp ())\n',
  'RP_PAVER.pat': '*RP_PAVER\n',
  'README.txt': 'RoadPro $v\n',
});

List<int> pfmZip(String v) => zipOf({
  'Project_Folder_Manager.exe': 'exe $v',
  'Project_Folder_Manager.hta': '<html>\n/*\n   PROJECT FOLDER MANAGER  v$v\n*/\n</html>',
  'READ_ME.txt': 'v$v',
  'dashboard_icon.ico': 'ico',
});

final slopeSetup = utf8.encode('pretend SlopeCalculator-Setup.exe 1.0.3');

FeedTool roadpro(List<int> zip, {String version = '3.5', String? sha, int? size}) => FeedTool(
  id: 'roadpro',
  name: 'RoadPro',
  platform: 'AutoCAD plugin',
  page: 'https://www.exceltokml.com/roadpro',
  version: version,
  download: FeedDownload(url: roadproUrl, file: 'RoadPro.zip', size: size ?? zip.length, sha256: sha ?? shaOf(zip)),
  install: builtInTools[1].install,
);

FeedTool pfm(List<int> zip, {String version = '6.3'}) => FeedTool(
  id: 'folder-manager',
  name: 'Project Folder Manager',
  platform: 'Windows',
  page: 'https://www.exceltokml.com/project-folder-manager',
  version: version,
  download: FeedDownload(url: pfmUrl, file: 'Project_Folder_Manager.zip', size: zip.length, sha256: shaOf(zip)),
  install: builtInTools[3].install,
);

FeedTool slope({String version = '1.0.3', String? sha}) => FeedTool(
  id: 'slope',
  name: 'Slope Calculator',
  platform: 'Web app and Windows',
  page: 'https://www.exceltokml.com/slope-calculation',
  version: version,
  download: FeedDownload(
    url: slopeUrl,
    file: 'SlopeCalculator-Setup.exe',
    size: slopeSetup.length,
    sha256: sha ?? shaOf(slopeSetup),
  ),
  install: builtInTools[4].install,
);

/// A PC in a temporary folder with a fake registry and fake running programs
class FakePc {
  FakePc() : root = Directory.systemTemp.createTempSync('toolkit-test-') {
    places = Places(localAppData: p.join(root.path, 'Local'), appData: p.join(root.path, 'Roaming'));
    detector = WindowsDetector(places: places, registry: (key) async => registry[key]);
  }
  final Directory root;
  late final Places places;
  late final WindowsDetector detector;
  final registry = <String, Map<String, String>>{};
  final running = <String>{};
  final runs = <List<String>>[];
  final shortcuts = <String>[];
  final served = <String, List<int>>{};

  /// What the fake installer does when run
  int Function(String exe, List<String> args) onRun = (_, _) => 0;

  String get slopeFolder => p.join(places.localAppData, 'SlopeCalculator');
  static const slopeKey = '${WindowsDetector.uninstallRoot}\\SlopeCalculator';

  void installSlope(String version) {
    Directory(slopeFolder).createSync(recursive: true);
    File(p.join(slopeFolder, 'SlopeCalculator.exe')).writeAsStringSync('exe');
    File(p.join(slopeFolder, 'Uninstall.exe')).writeAsStringSync('uninstall');
    registry[slopeKey] = {'DisplayVersion': version, 'InstallLocation': slopeFolder};
  }

  ToolInstaller installer({Detector? detector}) => ToolInstaller(
    places: places,
    detector: detector ?? this.detector,
    client: MockClient((req) async {
      final b = served[req.url.toString()];
      return b == null ? http.Response('not found', 404) : http.Response.bytes(b, 200);
    }),
    run: (exe, args) async {
      runs.add([exe, ...args]);
      return onRun(exe, args);
    },
    isRunning: (name) async => running.contains(name),
    shortcut: ({required link, required target, required folder}) async => shortcuts.add('$link -> $target'),
    waitForUninstall: const Duration(seconds: 2),
    waitForInstall: const Duration(seconds: 2),
  );

  void dispose() => root.deleteSync(recursive: true);
}

void main() {
  late FakePc pc;
  setUp(() => pc = FakePc());
  tearDown(() => pc.dispose());

  group('what is trusted', () {
    test('downloads only from the website and the owner\'s GitHub releases, over HTTPS', () {
      expect(isAllowedDownload(roadproUrl), isTrue);
      expect(isAllowedDownload(slopeUrl), isTrue);
      expect(isAllowedDownload('https://github.com/someone-else/x/releases/download/v1/x.exe'), isFalse);
      expect(isAllowedDownload('https://github.com/Asjad-Mehmood/x/archive/main.zip'), isFalse);
      expect(isAllowedDownload('http://www.exceltokml.com/roadpro/RoadPro.zip'), isFalse);
      expect(isAllowedDownload('https://exceltokml.com.evil.example/x.zip'), isFalse);
    });

    test('reads tasklist output', () {
      const out = '"ExcelToKML.exe","4120","Console","1","52,344 K"\r\n';
      expect(tasklistHas(out, 'ExcelToKML.exe'), isTrue);
      expect(tasklistHas(out, 'exceltokml.exe'), isTrue);
      expect(tasklistHas('INFO: No tasks are running which match the specified criteria.', 'ExcelToKML.exe'), isFalse);
    });
  });

  group('RoadPro as an AutoCAD bundle', () {
    test('installs: the plugin, its hatch, and a PackageContents.xml that loads it at start-up', () async {
      final zip = roadproZip('3.5');
      pc.served[roadproUrl] = zip;
      final r = await pc.installer().install(roadpro(zip));
      expect(r.ok, isTrue, reason: r.message);
      expect(r.message, 'RoadPro 3.5 is installed.');
      final b = pc.places.roadproBundle;
      expect(File(p.join(b, 'Contents', 'RoadPro.lsp')).existsSync(), isTrue);
      expect(File(p.join(b, 'Contents', 'RP_PAVER.pat')).existsSync(), isTrue);
      final xml = File(p.join(b, 'PackageContents.xml')).readAsStringSync();
      expect(xml, contains('AppVersion="3.5"'));
      expect(xml, contains('ModuleName="./Contents/RoadPro.lsp"'));
      expect(xml, contains('LoadOnAutoCADStartup="True"'));
      expect(xml, contains('SeriesMin="R19.1"'));
      expect((await pc.detector.find(roadpro(zip))).version, '3.5');
      // the download is not left behind
      expect(Directory(pc.places.downloads).listSync(), isEmpty);
    });

    test('updates in place, with nothing left over from the swap', () async {
      final old = roadproZip('3.4'), fresh = roadproZip('3.5');
      pc.served[roadproUrl] = old;
      await pc.installer().install(roadpro(old, version: '3.4'));
      pc.served[roadproUrl] = fresh;
      final current = await pc.detector.find(roadpro(fresh));
      final r = await pc.installer().install(roadpro(fresh), current: current);
      expect(r.message, 'RoadPro is updated to 3.5.');
      expect(Directory('${pc.places.roadproBundle}.old').existsSync(), isFalse);
      expect(Directory('${pc.places.roadproBundle}.new').existsSync(), isFalse);
    });

    test('a download that doesn\'t match its SHA-256 is deleted and nothing is installed', () async {
      final zip = roadproZip('3.5');
      pc.served[roadproUrl] = zip;
      final r = await pc.installer().install(roadpro(zip, sha: 'a' * 64));
      expect(r.ok, isFalse);
      expect(r.message, contains('SHA-256'));
      expect(Directory(pc.places.roadproBundle).existsSync(), isFalse);
      expect(Directory(pc.places.downloads).listSync(), isEmpty);
    });

    test('an incomplete download is refused', () async {
      final zip = roadproZip('3.5');
      pc.served[roadproUrl] = zip.sublist(0, zip.length - 10);
      final r = await pc.installer().install(roadpro(zip));
      expect(r.ok, isFalse);
      expect(r.message, contains('incomplete'));
      expect(Directory(pc.places.roadproBundle).existsSync(), isFalse);
    });

    test('a zip without the expected files is refused', () async {
      final zip = zipOf({'README.txt': 'nothing else'});
      pc.served[roadproUrl] = zip;
      final r = await pc.installer().install(roadpro(zip));
      expect(r.ok, isFalse);
      expect(r.message, contains('missing RoadPro.lsp'));
      expect(Directory(pc.places.roadproBundle).existsSync(), isFalse);
    });

    test('a file inside the zip can\'t escape its folder', () async {
      final zip = zipOf({
        '../../evil.lsp': 'x',
        'RoadPro.lsp': ';;; Version : 3.5',
        'RP_PAVER.pat': 'p',
        'README.txt': 'r',
      });
      pc.served[roadproUrl] = zip;
      final r = await pc.installer().install(roadpro(zip));
      expect(r.ok, isTrue, reason: r.message);
      expect(File(p.join(pc.root.path, 'evil.lsp')).existsSync(), isFalse);
      expect(File(p.join(pc.places.roadproBundle, 'Contents', 'evil.lsp')).existsSync(), isFalse);
    });

    test('uninstall removes the bundle', () async {
      final zip = roadproZip('3.5');
      pc.served[roadproUrl] = zip;
      await pc.installer().install(roadpro(zip));
      final r = await pc.installer().uninstall(roadpro(zip), await pc.detector.find(roadpro(zip)));
      expect(r.ok, isTrue, reason: r.message);
      expect(Directory(pc.places.roadproBundle).existsSync(), isFalse);
    });
  });

  group('Project Folder Manager', () {
    test('installs into the Toolkit\'s folder with a Start menu shortcut', () async {
      final zip = pfmZip('6.3');
      pc.served[pfmUrl] = zip;
      final r = await pc.installer().install(pfm(zip));
      expect(r.ok, isTrue, reason: r.message);
      expect(File(p.join(pc.places.folderManager, 'Project_Folder_Manager.hta')).existsSync(), isTrue);
      expect(pc.shortcuts.single, contains('Project Folder Manager.lnk'));
      expect(pc.shortcuts.single, endsWith('Project_Folder_Manager.exe'));
    });

    test('an update keeps the user\'s settings file', () async {
      pc.served[pfmUrl] = pfmZip('6.2');
      await pc.installer().install(pfm(pfmZip('6.2'), version: '6.2'));
      final config = File(p.join(pc.places.folderManager, 'Project_Folder_Manager_config.txt'))
        ..writeAsStringSync('ROOT=D:\\Projects');
      final zip = pfmZip('6.3');
      pc.served[pfmUrl] = zip;
      final r = await pc.installer().install(pfm(zip), current: await pc.detector.find(pfm(zip)));
      expect(r.message, 'Project Folder Manager is updated to 6.3.');
      expect(config.readAsStringSync(), 'ROOT=D:\\Projects');
    });

    test('a copy the user unzipped is updated where it is, without a shortcut', () async {
      final own = Directory(p.join(pc.root.path, 'D', 'PFM'))..createSync(recursive: true);
      File(p.join(own.path, 'Project_Folder_Manager.hta')).writeAsStringSync('PROJECT FOLDER MANAGER  v6.2');
      // the app's detector knows the folder the user chose
      final detector = WindowsDetector(
        places: pc.places,
        folderManagerFolder: () => own.path,
        registry: (_) async => null,
      );
      final zip = pfmZip('6.3');
      pc.served[pfmUrl] = zip;
      final r = await pc.installer(detector: detector).install(pfm(zip), current: await detector.find(pfm(zip)));
      expect(r.ok, isTrue, reason: r.message);
      expect(File(p.join(own.path, 'Project_Folder_Manager.hta')).readAsStringSync(), contains('v6.3'));
      expect(Directory(pc.places.folderManager).existsSync(), isFalse);
      expect(pc.shortcuts, isEmpty);
    });

    test('open: nothing is done', () async {
      pc.running.add('Project_Folder_Manager.exe');
      final r = await pc.installer().install(pfm(pfmZip('6.3')));
      expect(r.blocked, isTrue);
      expect(r.message, 'Close Project Folder Manager first, then press Install again.');
      expect(Directory(pc.places.folderManager).existsSync(), isFalse);
    });

    test('uninstall removes the program files and keeps the settings file', () async {
      final zip = pfmZip('6.3');
      pc.served[pfmUrl] = zip;
      await pc.installer().install(pfm(zip));
      File(p.join(pc.places.folderManager, 'Project_Folder_Manager_config.txt')).writeAsStringSync('x');
      final r = await pc.installer().uninstall(pfm(zip), await pc.detector.find(pfm(zip)));
      expect(r.message, 'Project Folder Manager is removed. Your settings file is kept for next time.');
      expect(File(p.join(pc.places.folderManager, 'Project_Folder_Manager.hta')).existsSync(), isFalse);
      expect(File(p.join(pc.places.folderManager, 'Project_Folder_Manager_config.txt')).existsSync(), isTrue);
    });

    test('a copy the Toolkit didn\'t install is not removed by it', () async {
      final why = pc.installer().cannotUninstall(
        pfm(pfmZip('6.3')),
        const Installed(version: '6.2', folder: r'D:\Mine'),
      );
      expect(why, contains('was not installed by the Toolkit'));
    });
  });

  group('a program with an installer (Slope Calculator)', () {
    setUp(() {
      pc.served[slopeUrl] = slopeSetup;
      // the fake installer: what the real one does to the registry
      pc.onRun = (exe, args) {
        if (p.basename(exe) == 'SlopeCalculator-Setup.exe') pc.installSlope('1.0.3');
        if (p.basename(exe) == 'Uninstall.exe') pc.registry.remove(FakePc.slopeKey);
        return 0;
      };
    });

    test('updates with the official installer, silently, from the downloads folder', () async {
      pc.installSlope('1.0.2');
      final r = await pc.installer().install(slope(), current: await pc.detector.find(slope()));
      expect(r.ok, isTrue, reason: r.message);
      expect(r.message, 'Slope Calculator is updated to 1.0.3.');
      expect(pc.runs.single.skip(1), ['/S']);
      expect(p.dirname(pc.runs.single.first), pc.places.downloads);
      expect(File(pc.runs.single.first).existsSync(), isFalse, reason: 'the installer is deleted afterwards');
    });

    test('open: never run its installer (it would close the program by force)', () async {
      pc.installSlope('1.0.2');
      pc.running.add('SlopeCalculator.exe');
      final r = await pc.installer().install(slope(), current: await pc.detector.find(slope()));
      expect(r.blocked, isTrue);
      expect(r.message, 'Close Slope Calculator first, then press Update again.');
      expect(pc.runs, isEmpty);
    });

    test('an installer that fails', () async {
      pc.onRun = (_, _) => 2;
      final r = await pc.installer().install(slope());
      expect(r.ok, isFalse);
      expect(r.message, contains('stopped (code 2)'));
    });

    test('installed, but not the version expected', () async {
      pc.onRun = (exe, args) {
        pc.installSlope('1.0.1');
        return 0;
      };
      final r = await pc.installer().install(slope());
      expect(r.ok, isFalse);
      expect(r.message, 'Slope Calculator was installed, but the version found is 1.0.1, not 1.0.3.');
    });

    test('a wrong SHA-256: the installer never runs', () async {
      final r = await pc.installer().install(slope(sha: 'b' * 64));
      expect(r.ok, isFalse);
      expect(pc.runs, isEmpty);
    });

    test('no download in the feed: nothing is tried', () async {
      final t = FeedTool(
        id: 'slope',
        name: 'Slope Calculator',
        platform: '',
        page: '',
        version: '1.0.3',
        install: builtInTools[4].install,
      );
      final r = await pc.installer().install(t);
      expect(r.ok, isFalse);
      expect(r.message, contains('can\'t be checked'));
    });

    test('uninstall runs its own uninstaller and waits until Windows no longer lists it', () async {
      pc.installSlope('1.0.3');
      final r = await pc.installer().uninstall(slope(), await pc.detector.find(slope()));
      expect(r.ok, isTrue, reason: r.message);
      expect(p.basename(pc.runs.single.first), 'Uninstall.exe');
      expect(pc.runs.single.skip(1), ['/S']);
    });

    test('an uninstaller that leaves it listed', () async {
      pc.installSlope('1.0.3');
      pc.onRun = (_, _) => 0;
      final r = await pc.installer().uninstall(slope(), await pc.detector.find(slope()));
      expect(r.ok, isFalse);
      expect(r.message, contains('still listed'));
    });

    test('every step goes into the log', () async {
      pc.installSlope('1.0.2');
      await pc.installer().install(slope(), current: await pc.detector.find(slope()));
      final log = File(pc.places.log).readAsStringSync();
      expect(log, contains('update slope 1.0.2 -> 1.0.3'));
      expect(log, contains('sha256 ${shaOf(slopeSetup)}'));
      expect(log, contains('done: 1.0.3'));
    });
  });

  group('command line for the Windows test', () {
    test('--install with a feed file writes the result', () async {
      final zip = roadproZip('3.5');
      pc.served[roadproUrl] = zip;
      final feed = File(p.join(pc.root.path, 'feed.json'))
        ..writeAsStringSync(
          jsonEncode({
            'schema': 1,
            'tools': [
              {
                'id': 'roadpro',
                'name': 'RoadPro',
                'platform': 'AutoCAD plugin',
                'page': 'https://www.exceltokml.com/roadpro',
                'version': '3.5',
                'download': {'url': roadproUrl, 'file': 'RoadPro.zip', 'size': zip.length, 'sha256': shaOf(zip)},
                'install': {
                  'kind': 'autocad-bundle',
                  'files': ['RoadPro.lsp', 'RP_PAVER.pat', 'README.txt'],
                  'main': 'RoadPro.lsp',
                },
              },
            ],
          }),
        );
      final out = p.join(pc.root.path, 'out.json');
      final args = ['--install=roadpro', '--feed=${feed.path}', '--result=$out'];
      expect(isCommandLine(args), isTrue);
      final code = await runCommandLine(args, places: pc.places, detector: pc.detector, installer: pc.installer());
      expect(code, 0);
      expect(jsonDecode(File(out).readAsStringSync()), {
        'ok': true,
        'blocked': false,
        'message': 'RoadPro 3.5 is installed.',
        'version': '3.5',
      });
    });

    test('a missing feed or tool is an error, not a crash', () async {
      final out = p.join(pc.root.path, 'out.json');
      expect(await runCommandLine(['--install=roadpro', '--result=$out'], places: pc.places, detector: pc.detector), 1);
      expect(
        await runCommandLine(
          ['--install=nope', '--feed=${p.join(pc.root.path, 'missing.json')}', '--result=$out'],
          places: pc.places,
          detector: pc.detector,
        ),
        1,
      );
      expect(jsonDecode(File(out).readAsStringSync())['ok'], isFalse);
    });
  });
}
