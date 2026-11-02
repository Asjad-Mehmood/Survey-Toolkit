import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

Future<void> main(List<String> args) async {
  // the Windows test: find, install or remove a tool, write the result and close
  if (isCommandLine(args)) exit(await runCommandLine(args));

  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final account = Account(Api(base: apiBase, client: http.Client()), store);
  final places = Places.windows();
  final detector = WindowsDetector(places: places, folderManagerFolder: () => store.read(ToolkitModel.folderKey));
  final model = ToolkitModel(
    account: account,
    store: store,
    detector: detector,
    installer: ToolInstaller(places: places, detector: detector),
  );
  runApp(ToolkitApp(account: account, model: model, settings: AppSettings(store)));
}
