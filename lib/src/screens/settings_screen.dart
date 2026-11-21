// Settings, at the foot of the sidebar: how the Toolkit looks, how tools are updated, the account
// and what this Toolkit is.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../brand.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../update/auto_update.dart';
import 'tools_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.model, required this.account, required this.settings, this.auto});
  final ToolkitModel model;
  final Account account;
  final AppSettings settings;
  final AutoUpdater? auto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = account.user;
    Widget row(String title, Widget trailing, {String? detail}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.ink),
              ),
              if (detail != null) Text(detail, style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ),
          trailing,
        ],
      ),
    );

    return Scaffold(
      appBar: const PageHeader(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panel(
                    title: 'Appearance',
                    children: [
                      row(
                        'Theme',
                        SegmentedButton<ThemeMode>(
                          key: const ValueKey('theme'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: ThemeMode.system, label: Text('As Windows')),
                            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (s) => settings.themeMode = s.first,
                        ),
                      ),
                    ],
                  ),
                  if (auto != null && model.installer != null) ...[
                    const SizedBox(height: 22),
                    UpdatesSection(model: model, auto: auto!),
                  ],
                  if (user != null) ...[
                    const SizedBox(height: 22),
                    Panel(
                      title: 'Account',
                      children: [
                        row(
                          user.display,
                          OutlinedButton.icon(
                            onPressed: account.signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign out'),
                          ),
                          detail: user.email,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Panel(
                    title: 'About',
                    children: [
                      row(
                        appName,
                        TextButton(
                          onPressed: () =>
                              launchUrl(Uri.parse('$websiteUrl/toolkit'), mode: LaunchMode.externalApplication),
                          child: const Text('exceltokml.com/toolkit'),
                        ),
                        detail: 'Version $appVersion · $appPublisher',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
