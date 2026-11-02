import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import 'src/account/account.dart';
import 'src/account/api.dart';
import 'src/app.dart';
import 'src/brand.dart';
import 'src/cli.dart';
import 'src/state/store.dart';
import 'src/toolkit/detect.dart';
import 'src/toolkit/installer.dart';
import 'src/toolkit/toolkit_model.dart';
import 'src/ui/settings.dart';
import 'src/update/background.dart';
import 'src/workspace/workspace_shell.dart';

Future<void> main(List<String> args) async {
  // the Windows test: find, install or remove a tool, write the result and close
  if (isCommandLine(args)) exit(await runCommandLine(args));

  WidgetsFlutterBinding.ensureInitialized();
  final places = Places.windows();
  // the web apps' own browser data (their sign-in, offline copies) in the Toolkit's folder;
  // the Toolkit's uninstaller removes it
  try {
    await WebviewController.initializeEnvironment(userDataPath: p.join(places.toolkit, 'WebView'));
  } catch (_) {
    // no WebView2 on this PC: the workspace says so when an app is opened
  }
  // the Windows test: one web app inside the Toolkit's window, for a screenshot
  final preview = argValue(args, 'preview');
  if (preview != null) return runApp(WorkspacePreview(appId: preview));
  final store = await Store.open();
  final account = Account(Api(base: apiBase, client: http.Client()), store);
  final detector = WindowsDetector(places: places, folderManagerFolder: () => store.read(ToolkitModel.folderKey));
  final model = ToolkitModel(
    account: account,
    store: store,
    detector: detector,
    installer: ToolInstaller(places: places, detector: detector),
  );
  // the tray icon; started by Windows at sign-in (--tray) the window stays hidden until opened
  final tray = WindowsTray();
  await tray.start();
  runApp(
    ToolkitApp(
      account: account,
      model: model,
      settings: AppSettings(store),
      background: Background(tray: tray, startup: WindowsStartup()),
    ),
  );
}
