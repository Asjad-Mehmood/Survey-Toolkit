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
import 'src/toolkit/toolkit_model.dart';
import 'src/ui/settings.dart';

Future<void> main(List<String> args) async {
  // the Windows test: look for the tools, write what was found and close
  final target = detectTarget(args);
  if (target != null) {
    await runDetect(target);
    exit(0);
  }
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final account = Account(Api(base: apiBase, client: http.Client()), store);
  final model = ToolkitModel(
    account: account,
    store: store,
    detector: WindowsDetector(folderManagerFolder: () => store.read(ToolkitModel.folderKey)),
  );
  runApp(ToolkitApp(account: account, model: model, settings: AppSettings(store)));
}
