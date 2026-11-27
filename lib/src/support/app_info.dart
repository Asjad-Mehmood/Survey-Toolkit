// What the Help box and Report a problem say about the Survey Toolkit
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import 'help.dart';

final appInfo = AppInfo(
  name: appName,
  version: appVersion,
  publisher: appPublisher,
  program: 'toolkit',
  guideUrl: '$websiteUrl/toolkit',
  whatsNewUrl: '$websiteUrl/whats-new/survey-toolkit',
  openUrl: (url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  },
  icon: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/brand/icon-512.png')),
);

/// The keys the Toolkit knows
Future<void> showShortcuts(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Keyboard shortcuts'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (keys, what) in [
          ('Ctrl+1', 'Home'),
          ('Ctrl+2 … Ctrl+7', 'The apps, in the order of the sidebar'),
          ('Ctrl+,', 'Settings'),
          ('F1', 'Help'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(keys, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Flexible(child: Text(what)),
              ],
            ),
          ),
      ],
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
  ),
);
