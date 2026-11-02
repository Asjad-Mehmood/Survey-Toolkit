// Pictures of the Toolkit's screens with its real fonts, for docs and for the owner to see them.
// Only when SHOTS_DIR is set:  SHOTS_DIR=/tmp/shots flutter test test/shots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/installer.dart';

import 'fakes.dart';

final _dir = Platform.environment['SHOTS_DIR'];

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    if (_dir == null) return;
    await _font('Inter', [
      for (final w in ['400Regular', '500Medium', '600SemiBold', '700Bold', '800ExtraBold'])
        'assets/fonts/Inter_$w.ttf',
    ]);
    await _font('JetBrainsMono', [
      'assets/fonts/JetBrainsMono_500Medium.ttf',
      'assets/fonts/JetBrainsMono_700Bold.ttf',
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
    await _font('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shot(
    WidgetTester t,
    String name,
    Harness h,
    Size size, {
    bool dark = false,
    Future<void> Function()? before,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    h.settings.themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: h.app));
    await settle(t);
    if (before != null) await before();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  const desktop = Size(1180, 900);
  testWidgets('screens', (t) async {
    await shot(t, '1-sign-in', Harness(site: FakeSite(), store: Store.memory()), desktop);
    await shot(
      t,
      '2-beta-closed',
      Harness(
        site: FakeSite()..tester = false,
        store: signedInStore(beta: 'unknown'),
      ),
      desktop,
    );
    await shot(t, '3-tools', Harness(site: FakeSite(), store: signedInStore()), desktop);
    await shot(t, '4-tools-dark', Harness(site: FakeSite(), store: signedInStore()), desktop, dark: true);
    await shot(t, '5-tools-phone-size', Harness(site: FakeSite(), store: signedInStore()), const Size(400, 860));

    final updating = FakeInstaller()..gate = Completer<void>();
    await shot(
      t,
      '6-updating',
      Harness(site: FakeSite(), store: signedInStore(), installer: updating),
      desktop,
      before: () async {
        await t.tap(find.text('Update'));
        await t.pump();
      },
    );
    updating.gate!.complete();
    await settle(t);

    final done = FakeInstaller()..next = const JobResult.done('Excel to KML is updated to 4.4.0.', version: '4.4.0');
    final blocked = FakeInstaller()
      ..next = const JobResult.blocked('Close Excel to KML first, then press Update again.');
    await shot(
      t,
      '7-updated',
      Harness(site: FakeSite(), store: signedInStore(), installer: done),
      desktop,
      before: () async {
        await t.tap(find.text('Update'));
        await settle(t);
      },
    );
    await shot(
      t,
      '8-tool-open',
      Harness(site: FakeSite(), store: signedInStore(), installer: blocked),
      desktop,
      before: () async {
        await t.tap(find.text('Update'));
        await settle(t);
      },
    );
  }, skip: _dir == null);
}
