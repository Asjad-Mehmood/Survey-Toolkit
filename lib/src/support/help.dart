// Help: About, What's new, the user guide, Report a problem, the error log and the open-source
// licences, the same in every program from SurveyX Digital.
import 'package:flutter/material.dart';

import 'crash_log.dart';

/// What the Help box says about the program
class AppInfo {
  const AppInfo({
    required this.name,
    required this.version,
    required this.publisher,
    required this.program,
    required this.guideUrl,
    required this.whatsNewUrl,
    required this.openUrl,
    this.legalese = '© 2026 SurveyX Digital',
    this.icon,
  });

  final String name;
  final String version;
  final String publisher;

  /// The program's name in the website's contact form (?program=)
  final String program;
  final String guideUrl;
  final String whatsNewUrl;
  final Future<void> Function(String url) openUrl;
  final String legalese;
  final Widget? icon;

  /// The website's contact form with the program, its version and the platform filled in
  String get reportUrl => Uri.https('www.surveyxdigital.com', '/contact', {
    'topic': 'problem',
    'program': program,
    'version': version,
    'platform': CrashLog.platform,
  }).toString();

  Future<void> report() => openUrl(reportUrl);
}

/// The Help box. [shortcuts] opens the program's keyboard shortcuts, when it has them.
Future<void> showHelp(BuildContext context, AppInfo info, {VoidCallback? shortcuts}) => showDialog<void>(
  context: context,
  builder: (context) => HelpDialog(info: info, shortcuts: shortcuts),
);

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key, required this.info, this.shortcuts});
  final AppInfo info;
  final VoidCallback? shortcuts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // the box closes first; what comes next opens from the window behind it
    final nav = Navigator.of(context);
    void go(Future<void> Function() action) {
      nav.pop();
      action();
    }

    Widget item(IconData icon, String label, String sub, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Dialog(
      key: const ValueKey('help'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (info.icon != null) ...[
                      SizedBox(width: 44, height: 44, child: info.icon),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            'Version ${info.version} · ${info.publisher}',
                            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              item(
                Icons.new_releases_outlined,
                "What's new",
                'The changes in each version',
                () => go(() => info.openUrl(info.whatsNewUrl)),
              ),
              item(
                Icons.menu_book_outlined,
                'User guide',
                'How to use ${info.name}',
                () => go(() => info.openUrl(info.guideUrl)),
              ),
              if (shortcuts != null)
                item(Icons.keyboard_outlined, 'Keyboard shortcuts', 'The keys that save time', () {
                  nav.pop();
                  shortcuts!();
                }),
              item(
                Icons.bug_report_outlined,
                'Report a problem',
                'Tell us what went wrong; the version is sent with it',
                () => go(info.report),
              ),
              if (CrashLog.path != null)
                item(
                  Icons.folder_open_outlined,
                  'Error log',
                  'The file to attach when you report a problem',
                  () => go(CrashLog.openFolder),
                ),
              item(Icons.gavel_outlined, 'Open-source licences', 'The free software ${info.name} is built with', () {
                nav.pop();
                showLicensePage(
                  context: nav.context,
                  applicationName: info.name,
                  applicationVersion: 'Version ${info.version}',
                  applicationLegalese: info.legalese,
                  applicationIcon: info.icon == null ? null : SizedBox(width: 56, height: 56, child: info.icon),
                );
              }),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
