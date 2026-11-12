// RoadPro's page in the workspace: the AutoCAD list from the registry, the command list from the
// website, and the page itself.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/roadpro/roadpro_panel.dart';
import 'package:survey_toolkit/src/roadpro/roadpro_pc.dart';
import 'package:survey_toolkit/src/state/store.dart';

import 'fakes.dart';

const _locations = r'''

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\ACAD-7101:409
    AcadLocation    REG_SZ    C:\Program Files\Autodesk\AutoCAD 2024

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\ACAD-7100:409
    AcadLocation    REG_SZ    "C:\Program Files\Autodesk\AutoCAD 2024"

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R25.0\ACAD-8101:409
    AcadLocation    REG_SZ    C:\Program Files\Autodesk\AutoCAD 2025

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R18.2\ACAD-A001:409
    AcadLocation    REG_SZ    C:\ACAD2012

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\Leftover
    AcadLocation    REG_SZ    C:\Nowhere

End of search: 5 match(es) found.
''';

const _names = r'''
HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\ACAD-7101:409
    ProductName    REG_SZ    Autodesk Civil 3D 2024

HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R24.3\ACAD-7100:409
    ProductName    REG_SZ    AutoCAD 2024
''';

void main() {
  group('AutoCAD on this PC', () {
    test('the registry search is read per key', () {
      final v = parseRegSearch(_locations);
      expect(v, hasLength(5));
      expect(
        v[r'HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD\R25.0\ACAD-8101:409'],
        r'C:\Program Files\Autodesk\AutoCAD 2025',
      );
    });

    test('products: newest first, names from ProductName, leftovers and quotes handled', () {
      final list = autocadProducts(parseRegSearch(_locations), parseRegSearch(_names));
      expect(list.map((a) => a.name), ['AutoCAD 2025', 'AutoCAD 2024', 'Autodesk Civil 3D 2024', 'AutoCAD 2012']);
      expect(list[1].folder, r'C:\Program Files\Autodesk\AutoCAD 2024');
      expect(list.first.exe, endsWith('acad.exe'));
      expect(list.first.year, 2025);
      expect(list.map((a) => a.supported), [true, true, true, false]);
    });

    test('no AutoCAD: an empty list', () {
      expect(autocadProducts(parseRegSearch(''), const {}), isEmpty);
    });
  });

  group('the command list from the website', () {
    test('only plain command names and allowed links are kept', () {
      final info = RoadProInfo.from({
        'commands': [
          {'short': 'RDP', 'full': 'ROADPRO', 'text': 'Build a road'},
          {'short': 'rdp; del', 'full': 'X', 'text': 'no'},
          {'short': 'RDX', 'full': 'ROADXSEC'},
          {'short': '—', 'full': 'ROADPRORESET', 'text': 'Settings back to the defaults'},
        ],
        'keys': [
          {'key': 'U', 'text': 'Undo'},
        ],
        'links': {'guide': 'https://www.exceltokml.com/roadpro/RoadPro_User_Guide.pdf', 'page': 'http://x.example/'},
      })!;
      expect(info.commands.map((c) => c.short), ['RDP', 'ROADPRORESET']);
      expect(info.keys, [('U', 'Undo')]);
      expect(info.links.keys, ['guide']);
    });

    test('nothing usable: null', () {
      expect(RoadProInfo.from({'commands': []}), isNull);
      expect(RoadProInfo.from('x'), isNull);
    });
  });

  group('the RoadPro page', () {
    Future<Harness> open(WidgetTester t, {FakeSite? site, Store? store}) async {
      t.view.physicalSize = const Size(1280, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final h = Harness(site: site ?? FakeSite(), store: store ?? signedInStore());
      await t.pumpWidget(h.app);
      await settle(t);
      await t.tap(find.text('RoadPro').first);
      await settle(t);
      return h;
    }

    testWidgets('is in the sidebar and lists the AutoCAD products', (t) async {
      final h = await open(t);
      expect(find.text('START AUTOCAD'), findsOneWidget);
      expect(find.text('Autodesk Civil 3D 2024'), findsOneWidget);
      expect(find.text('Too old for RoadPro'), findsOneWidget);
      // RoadPro isn't installed on the typical PC: it says to install it first
      expect(find.textContaining('Install RoadPro first'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('start R24.3 Autodesk Civil 3D 2024')));
      await settle(t);
      expect(h.roadproPc.started.single, endsWith(r'AutoCAD 2024\acad.exe'));
      expect(find.textContaining('is starting'), findsOneWidget);

      // the 2012 one can't be started
      final old = t.widget<FilledButton>(find.byKey(const ValueKey('start R18.2 AutoCAD 2012')));
      expect(old.onPressed, isNull);
    });

    testWidgets('commands: from the website, searchable, a press copies one', (t) async {
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final h = await open(t);
      expect(find.text('RDP'), findsOneWidget);
      expect(find.text('RDJ'), findsOneWidget);
      expect(find.text('bad cmd'), findsNothing);
      expect(find.text('Undo the whole road in one step'), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('roadpro search')), 'taper');
      await settle(t);
      expect(find.text('RDT'), findsOneWidget);
      expect(find.text('RDP'), findsNothing);

      await t.tap(find.text('RDT'));
      await settle(t);
      expect(copied, ['RDT']);
      expect(find.textContaining('RDT copied'), findsOneWidget);

      // kept for when the PC is offline
      expect(h.store.readJson(RoadProPanel.infoKey), isNotNull);
    });

    testWidgets('help: the guide, the page and RoadPro Hub; a link not on the site is left out', (t) async {
      final h = await open(t);
      expect(find.widgetWithText(OutlinedButton, 'User guide'), findsOneWidget);
      final keys = t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Shortcut keys'));
      expect(keys.onPressed, isNull);
      await t.tap(find.widgetWithText(OutlinedButton, 'RoadPro Hub'));
      await settle(t);
      expect(h.roadproPc.started.single, endsWith('RoadProHub.exe'));
    });

    testWidgets('website down: the last copy, or a message', (t) async {
      final store = signedInStore()
        ..writeJson(RoadProPanel.infoKey, {
          'commands': [
            {'short': 'RDB', 'full': 'ROADREBUILD', 'text': 'Rebuild'},
          ],
        });
      await open(t, site: FakeSite()..roadproInfo = false, store: store);
      expect(find.text('RDB'), findsOneWidget);
    });

    testWidgets('website down and nothing kept: says so', (t) async {
      await open(t, site: FakeSite()..roadproInfo = false);
      expect(find.textContaining('can\'t be loaded just now'), findsOneWidget);
    });
  });
}
