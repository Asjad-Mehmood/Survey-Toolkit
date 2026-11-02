// Automatic updates (T5): which tools update by themselves, when, what the user is told, the
// Updates section, running in the background, and the --auto-update command line.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/account/account.dart';
import 'package:survey_toolkit/src/account/api.dart';
import 'package:survey_toolkit/src/cli.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/feed.dart';
import 'package:survey_toolkit/src/toolkit/installer.dart';
import 'package:survey_toolkit/src/toolkit/toolkit_model.dart';
import 'package:survey_toolkit/src/update/auto_update.dart';
import 'package:survey_toolkit/src/update/background.dart';
import 'package:survey_toolkit/src/update/update_prefs.dart';

import 'fakes.dart';

final feed = Feed.from(jsonDecode(File('test/fixtures/feed.json').readAsStringSync()))!;
FeedTool tool(String id) => feed.tools.firstWhere((t) => t.id == id);

/// Every tool installed, each one version behind (the feed has Excel to KML 4.4.0, RoadPro 3.4,
/// Traverse 2.1.0, Folder Manager 6.2, Slope 1.0.3)
Map<String, Installed> allBehind() => {
  'excel-to-kml': const Installed(version: '4.3.1', folder: r'C:\X', program: r'C:\X\ExcelToKML.exe'),
  'roadpro': const Installed(version: '3.3', folder: r'C:\R'),
  'traverse': const Installed(version: '2.0.0', folder: r'C:\T', program: r'C:\T\TraverseLevel.exe'),
  'folder-manager': const Installed(version: '6.1', folder: r'C:\F', program: r'C:\F\Project_Folder_Manager.exe'),
  'slope': const Installed(version: '1.0.2', folder: r'C:\S', program: r'C:\S\SlopeCalculator.exe'),
};

void main() {
  group('which tools update by themselves', () {
    test('Automatic tools with a new version, closed: now; never one that isn\'t installed', () {
      final found = allBehind()..remove('folder-manager');
      final plan = planUpdates(
        tools: feed.tools,
        installed: (id) => found[id] ?? Installed.none,
        modeOf: (_) => UpdateMode.automatic,
      );
      expect(plan.now.map((t) => t.id), ['roadpro', 'slope']);
      // Excel to KML and Traverse open themselves after their installer: when opened from the Toolkit
      expect(plan.waiting, {'excel-to-kml': Waits.untilOpened, 'traverse': Waits.untilOpened});
    });

    test('Ask me, no download, given up at this version, up to date, no AutoCAD', () {
      final found = allBehind()..['folder-manager'] = const Installed(version: '6.2', folder: r'C:\F');
      final noDownload = [
        for (final t in feed.tools)
          t.id == 'slope'
              ? FeedTool(
                  id: t.id,
                  name: t.name,
                  platform: t.platform,
                  page: t.page,
                  install: t.install,
                  version: '1.0.3',
                )
              : t,
      ];
      final plan = planUpdates(
        tools: noDownload,
        installed: (id) => found[id],
        modeOf: (id) => id == 'excel-to-kml' ? UpdateMode.ask : UpdateMode.automatic,
        gaveUp: {'roadpro': '3.4'},
      );
      expect(plan.now, isEmpty);
      expect(plan.waiting, {
        'excel-to-kml': Waits.askMe,
        'roadpro': Waits.gaveUp,
        'traverse': Waits.untilOpened,
        'slope': Waits.noDownload,
      });
      // a newer RoadPro than the one given up on is tried again
      expect(
        planUpdates(
          tools: feed.tools,
          installed: (id) => found[id],
          modeOf: (_) => UpdateMode.automatic,
          gaveUp: {'roadpro': '3.3.9'},
        ).now.map((t) => t.id),
        contains('roadpro'),
      );
      // still looking on this PC: nothing yet
      expect(planUpdates(tools: feed.tools, installed: (_) => null, modeOf: (_) => UpdateMode.automatic).now, isEmpty);
    });

    test('each tool\'s choice is remembered; Automatic is the default', () {
      final store = Store.memory();
      final prefs = UpdatePrefs(store);
      expect(prefs.modeOf('slope'), UpdateMode.automatic);
      prefs.setMode('slope', UpdateMode.ask);
      expect(UpdatePrefs(store).modeOf('slope'), UpdateMode.ask);
      expect(UpdatePrefs(store).modeOf('roadpro'), UpdateMode.automatic);
    });

    test('the notification', () {
      expect(updatedText([]), isNull);
      expect(updatedText([('RoadPro', '3.5')]), 'RoadPro updated to 3.5');
      expect(
        updatedText([('Slope Calculator', '1.0.3'), ('RoadPro', '3.5')]),
        'Updated: Slope Calculator 1.0.3, RoadPro 3.5',
      );
    });

    test('Start with Windows: the program, quoted, in the tray', () {
      expect(
        startCommand(r'C:\Users\A B\AppData\Local\Survey Toolkit\Program\SurveyToolkit.exe'),
        r'"C:\Users\A B\AppData\Local\Survey Toolkit\Program\SurveyToolkit.exe" --tray',
      );
      expect(startedInTray(['--tray']), isTrue);
      expect(startedInTray(['--detect=x']), isFalse);
    });
  });

  group('the automatic update', () {
    late FakeSite site;
    late FakeInstaller installer;
    late FakeTray tray;
    late FakeStartup startup;
    late ToolkitModel model;
    late AutoUpdater auto;

    Future<void> setUpPc(Map<String, Installed> found, {Duration retryOpen = const Duration(minutes: 30)}) async {
      site = FakeSite();
      final store = signedInStore();
      final account = Account(Api(base: 'https://www.exceltokml.com', client: site.client), store);
      await account.restore();
      installer = FakeInstaller();
      model = ToolkitModel(account: account, store: store, detector: FakeDetector(found), installer: installer);
      tray = FakeTray();
      startup = FakeStartup();
      auto = AutoUpdater(
        model: model,
        background: Background(tray: tray, startup: startup),
        retryOpen: retryOpen,
      );
      addTearDown(auto.dispose);
    }

    List<Map<String, Object?>> events() =>
        site.reports.expand((r) => (r['events']! as List).cast<Map<String, Object?>>()).toList();

    test('updates what is due with nobody pressing anything, says so, and tells the website', () async {
      await setUpPc(allBehind());
      installer.next = const JobResult.done('Updated.', version: '1.0.3');
      await auto.check();
      await Future<void>.delayed(Duration.zero);
      expect(installer.calls, ['install roadpro', 'install folder-manager', 'install slope']);
      expect(tray.notes, [
        'Survey Toolkit: Updated: RoadPro 1.0.3, Project Folder Manager 1.0.3, Slope Calculator 1.0.3',
      ]);
      expect(events().where((e) => e['action'] == 'updated').map((e) => e['message']), everyElement('automatic'));
      expect(events().map((e) => e['tool']), containsAll(['roadpro', 'folder-manager', 'slope']));
    });

    test('Ask me: left alone, the card keeps its Update button', () async {
      await setUpPc({'slope': allBehind()['slope']!});
      model.updates.setMode('slope', UpdateMode.ask);
      await auto.check();
      expect(installer.calls, isEmpty);
      expect(tray.notes, isEmpty);
    });

    test('a tool that is open: nothing on its card, tried again after a while', () async {
      await setUpPc({'slope': allBehind()['slope']!}, retryOpen: const Duration(milliseconds: 30));
      installer.next = const JobResult.blocked('Close Slope Calculator first, then press Update again.');
      await auto.check();
      expect(installer.calls, ['install slope']);
      expect(model.results, isEmpty);
      expect(tray.notes, isEmpty);
      expect(events().where((e) => e['tool'] == 'slope'), isEmpty);
      // closed now
      installer.next = const JobResult.done('Updated.', version: '1.0.3');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(installer.calls, ['install slope', 'install slope']);
      expect(tray.notes, ['Survey Toolkit: Slope Calculator updated to 1.0.3']);
    });

    test('after 3 failures at one version it stops, says so once, and leaves it to the Update button', () async {
      await setUpPc({'slope': allBehind()['slope']!});
      installer.next = const JobResult.failed('The download was damaged.');
      await model.refresh();
      for (var i = 0; i < 5; i++) {
        await auto.updateDue();
      }
      expect(installer.calls, ['install slope', 'install slope', 'install slope']);
      expect(auto.gaveUp, {'slope': '1.0.3'});
      expect(tray.notes, hasLength(1));
      expect(tray.notes.single, contains('Slope Calculator wasn\'t updated'));
      expect(model.results['slope']!.message, 'The download was damaged.');
      await Future<void>.delayed(Duration.zero);
      expect(events().where((e) => e['action'] == 'failed').first['message'], 'automatic: The download was damaged.');
    });

    test('waits while the user is installing something themselves', () async {
      await setUpPc(allBehind());
      installer
        ..gate = Completer<void>()
        ..next = const JobResult.done('Done.', version: '1.0.3');
      await model.refresh();
      final mine = model.install(tool('folder-manager'));
      final updated = await auto.updateDue();
      expect(updated, isEmpty);
      installer.gate!.complete();
      await mine;
      expect(installer.calls, ['install folder-manager']);
    });

    test('Excel to KML set to Automatic: opening it from the Toolkit updates it first, and it opens', () async {
      await setUpPc({'excel-to-kml': allBehind()['excel-to-kml']!});
      installer.next = const JobResult.done('Excel to KML is updated to 4.4.0.', version: '4.4.0');
      await auto.check();
      expect(installer.calls, isEmpty, reason: 'it would open itself in the middle of other work');
      expect(model.updatesOnOpen(tool('excel-to-kml')), isTrue);
      // its installer opens the new version
      expect(await model.open(tool('excel-to-kml')), isTrue);
      expect(installer.calls, ['install excel-to-kml']);
      // set to Ask me: opening it just opens it
      model.updates.setMode('excel-to-kml', UpdateMode.ask);
      expect(model.updatesOnOpen(tool('excel-to-kml')), isFalse);
    });

    test('every 4 hours, and the tray\'s Check for updates now', () async {
      await setUpPc({'slope': allBehind()['slope']!});
      installer.next = const JobResult.blocked('Close it.');
      auto.start();
      expect(auto.nextCheck, isNotNull);
      expect(tray.checkNow, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(installer.calls, ['install slope']);
      tray.checkNow!();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(installer.calls, ['install slope', 'install slope']);
      auto.stop();
      expect(auto.nextCheck, isNull);
      expect(tray.checkNow, isNull);
    });

    test('Start with Windows: on keeps the Toolkit in the tray; Windows saying no is shown', () async {
      await setUpPc(const {});
      final bg = auto.background;
      startup.on = true;
      await bg.load();
      expect(bg.on, isTrue);
      expect(startup.sets, [true], reason: 'the Run value is written again, in case the Toolkit moved');
      expect(tray.kept, isTrue);
      expect(await bg.setOn(false), isTrue);
      expect(tray.kept, isFalse);
      startup.works = false;
      expect(await bg.setOn(true), isFalse);
      expect(bg.on, isFalse);
      expect(bg.problem, isNotNull);
    });
  });

  group('the Tools page', () {
    testWidgets('the Updates section: the switch, and Automatic or Ask me for each installed tool', (t) async {
      t.view.physicalSize = const Size(1280, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final h = Harness(site: FakeSite(), store: signedInStore());
      await t.pumpWidget(h.app);
      await settle(t);
      expect(find.text('Updates'), findsOneWidget);
      // installed on the typical PC: Excel to KML and Slope Calculator
      expect(find.byKey(const ValueKey('mode excel-to-kml')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode slope')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode roadpro')), findsNothing);
      expect(find.text('When you open it from the Toolkit'), findsOneWidget);
      // Excel to KML's card says when it updates
      expect(find.text('Updates by itself the next time you open it from the Toolkit.'), findsOneWidget);
      expect(h.installer is FakeInstaller && (h.installer! as FakeInstaller).calls.isEmpty, isTrue);

      final ask = find.descendant(of: find.byKey(const ValueKey('mode excel-to-kml')), matching: find.text('Ask me'));
      await t.ensureVisible(ask);
      await t.tap(ask);
      await settle(t);
      expect(h.model.updates.modeOf('excel-to-kml'), UpdateMode.ask);
      expect(UpdatePrefs(h.store).modeOf('excel-to-kml'), UpdateMode.ask);
      expect(find.text('Updates by itself the next time you open it from the Toolkit.'), findsNothing);

      final toggle = find.byKey(const ValueKey('background switch'));
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await settle(t);
      expect(h.startup.on, isTrue);
      expect(h.tray.kept, isTrue);
      expect(find.textContaining('Closing the window keeps the Toolkit in the tray'), findsOneWidget);
    });

    testWidgets('Check again updates what is set to Automatic', (t) async {
      t.view.physicalSize = const Size(1280, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final installer = FakeInstaller()..next = const JobResult.done('Slope Calculator is updated.', version: '1.0.3');
      final h = Harness(
        site: FakeSite(),
        store: signedInStore(),
        installer: installer,
        detector: FakeDetector({'slope': allBehind()['slope']!}),
      );
      await t.pumpWidget(h.app);
      await settle(t);
      // on start
      expect(installer.calls, ['install slope']);
      expect(h.tray.notes, ['Survey Toolkit: Slope Calculator updated to 1.0.3']);
      await t.tap(find.byTooltip('Check again'));
      await settle(t);
      expect(installer.calls, ['install slope', 'install slope']);
    });
  });

  group('the command line for the Windows test', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('toolkit-auto'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('--auto-update: updates what is due, writes what waits and why', () async {
      final feedFile = File('${dir.path}/feed.json')
        ..writeAsStringSync(File('test/fixtures/feed.json').readAsStringSync());
      final out = '${dir.path}/out.json';
      final installer = FakeInstaller()..next = const JobResult.done('Updated.', version: '1.0.3');
      final found = allBehind()..remove('roadpro');
      final code = await runCommandLine(
        ['--auto-update', '--feed=${feedFile.path}', '--result=$out', '--ask=folder-manager'],
        places: Places(localAppData: dir.path, appData: dir.path),
        detector: FakeDetector(found),
        installer: installer,
      );
      expect(code, 0);
      expect(installer.calls, ['install slope']);
      final j = jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>;
      expect(j['updated'], {'slope': '1.0.3'});
      expect(j['waiting'], {'excel-to-kml': 'untilOpened', 'traverse': 'untilOpened', 'folder-manager': 'askMe'});
      expect(j['notification'], 'Slope Calculator updated to 1.0.3');
    });

    test('--start-with-windows=on|off', () async {
      final out = '${dir.path}/out.json';
      final startup = FakeStartup();
      expect(await runCommandLine(['--start-with-windows=on', '--result=$out'], startup: startup), 0);
      expect(jsonDecode(File(out).readAsStringSync()), {'ok': true, 'on': true});
      expect(await runCommandLine(['--start-with-windows=off', '--result=$out'], startup: startup), 0);
      expect(startup.on, isFalse);
      expect(await runCommandLine(['--start-with-windows=maybe', '--result=$out'], startup: startup), 1);
      expect(isCommandLine(['--auto-update']), isTrue);
      expect(isCommandLine(['--tray']), isFalse);
    });
  });
}
