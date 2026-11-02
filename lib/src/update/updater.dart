// Self-update for the Toolkit. A few seconds after it opens, it looks at its releases on GitHub.
// When a higher version is there it asks; on Yes it downloads the installer, checks its SHA-256,
// runs it silently and closes; the installer opens the new version. Any network problem is
// ignored: the Toolkit carries on as normal.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../brand.dart';
import 'update_check.dart';

Future<void> checkForUpdate(BuildContext context) async {
  if (!Platform.isWindows || const bool.fromEnvironment('NO_UPDATE_CHECK')) return;
  await Future<void>.delayed(const Duration(seconds: 4));
  ReleaseFiles? files;
  UpdateInfo? info;
  try {
    final list = await http
        .get(
          Uri.parse('https://api.github.com/repos/$releasesRepo/releases?per_page=10'),
          headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'SurveyToolkit/$appVersion'},
        )
        .timeout(const Duration(seconds: 15));
    if (list.statusCode != 200) return;
    files = newestRelease(jsonDecode(list.body));
    if (files == null) return;
    final m = await http.get(Uri.parse(files.manifestUrl)).timeout(const Duration(seconds: 15));
    if (m.statusCode == 200) info = UpdateInfo.parse(m.body);
  } catch (_) {
    return; // offline or blocked: try again next time
  }
  if (!offersUpdate(info, appVersion) || !context.mounted) return;
  final update = info!;
  final release = files;

  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('A new version is ready'),
      content: Text(
        '$appName ${update.version} is available (you have $appVersion).\n\n'
        'Update now? The Toolkit closes, updates itself and opens again in a few seconds.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update now')),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context)
    ..showSnackBar(const SnackBar(content: Text('Downloading the update…'), duration: Duration(minutes: 5)));
  try {
    final r = await http.get(Uri.parse(release.installerUrl)).timeout(const Duration(minutes: 5));
    if (r.statusCode != 200) throw HttpException('the server answered ${r.statusCode}');
    if (!sha256Matches(r.bodyBytes, update.sha256)) {
      throw const FileSystemException('the download was damaged (checksum)');
    }
    final file = File('${Directory.systemTemp.path}\\SurveyToolkit-Update.exe');
    await file.writeAsBytes(r.bodyBytes, flush: true);
    await Process.start(file.path, ['/S', '/UPDATE'], mode: ProcessStartMode.detached);
    exit(0);
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('The update could not be downloaded. Nothing was changed. ($e)')));
  }
}
