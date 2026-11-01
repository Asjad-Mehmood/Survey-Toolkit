// The Tools page: one card per tool with what is installed on this PC, the latest version and
// what to do. T2 only looks: "Get it" and "Get the update" open the tool's page in the browser.
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../brand.dart';
import '../toolkit/feed.dart';
import '../toolkit/status.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.model, required this.account, required this.settings});
  final ToolkitModel model;
  final Account account;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/brand/icon-512.png', width: 32, height: 32, excludeFromSemantics: true),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                appName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            const Tag('Beta'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Check again',
            onPressed: model.busy ? null : model.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: brightness == Brightness.light ? 'Dark mode' : 'Light mode',
            onPressed: () => settings.cycleTheme(brightness),
            icon: Icon(brightness == Brightness.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'out') account.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(account.user?.display ?? '')),
              const PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.line),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: model.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Summary(model: model),
                    const SizedBox(height: 14),
                    const Notice(
                      'Beta, look only: the Toolkit shows what is on this PC and what is new. It doesn\'t install '
                      'or change anything yet. "Get it" opens the tool\'s page in your browser.',
                    ),
                    if (model.problem != null) ...[
                      const SizedBox(height: 10),
                      Notice(model.problem!, kind: NoticeKind.warning),
                    ],
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, box) {
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        final columns = box.maxWidth >= 760 * scale ? 2 : 1;
                        const gap = 14.0;
                        final width = (box.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final t in model.tools)
                              SizedBox(
                                width: width,
                                child: ToolCard(tool: t, model: model),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Version $appVersion · $appPublisher',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 12, fontFeatures: tabular),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// The banner: how many updates, how many installed, when last checked (kept current each minute)
class _Summary extends StatefulWidget {
  const _Summary({required this.model});
  final ToolkitModel model;

  @override
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final model = widget.model;
    final updates = model.countIn(ToolState.updateAvailable);
    final upToDate = model.countIn(ToolState.upToDate);
    final installed = upToDate + updates + model.countIn(ToolState.unknown);
    final headline = model.busy && model.checkedAt == null
        ? 'Checking your tools…'
        : model.noFeed
        ? 'Can\'t reach exceltokml.com yet'
        : updates > 0
        ? '$updates ${updates == 1 ? 'update' : 'updates'} available'
        : installed == 0
        ? 'None of the tools is installed yet'
        : 'Everything installed is up to date';
    final detail = [
      '$installed of ${model.tools.length} installed',
      if (model.checkedAt != null) 'checked ${_ago(model.checkedAt!)}${model.fromKept ? ' (offline)' : ''}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.heroStart, c.heroEnd]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            updates > 0 ? Icons.system_update_alt_rounded : Icons.verified_rounded,
            color: BrandColors.gold,
            size: 34,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    headline,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontFeatures: tabular),
                ),
              ],
            ),
          ),
          if (model.busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: BrandColors.gold),
            ),
        ],
      ),
    );
  }
}

IconData _iconOf(String id) => switch (id) {
  'excel-to-kml' => Icons.public_rounded,
  'roadpro' => Icons.alt_route_rounded,
  'traverse' => Icons.explore_outlined,
  'folder-manager' => Icons.folder_copy_outlined,
  'slope' => Icons.trending_up_rounded,
  _ => Icons.extension_outlined,
};

class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.tool, required this.model});
  final FeedTool tool;
  final ToolkitModel model;

  Future<void> _browse(BuildContext context, String url) async {
    if (!isAllowedUrl(url)) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('The browser could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final installed = model.installedOf(tool.id);
    final state = model.stateOfTool(tool);
    final (Color? tagColor, Color? tagText, IconData? tagIcon) = switch (state) {
      ToolState.upToDate => (c.rise, Colors.white, Icons.check_rounded),
      ToolState.updateAvailable => (c.accent, c.onAccent, Icons.arrow_upward_rounded),
      ToolState.needsAutocad => (null, null, Icons.block_rounded),
      _ => (null, null, null),
    };
    final latest = tool.version;
    final versions = switch (state) {
      ToolState.checking => 'Looking on this PC…',
      ToolState.updateAvailable => 'Installed ${installed!.version} → latest $latest',
      ToolState.upToDate => 'Installed ${installed!.version}, the latest',
      ToolState.unknown => 'Installed ${installed!.version}',
      _ => latest == null ? 'Not on this PC' : 'Latest $latest',
    };

    final buttons = <Widget>[
      if (installed?.program != null)
        FilledButton.icon(
          onPressed: () async {
            if (!await model.open(tool) && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tool.name} could not be opened.')));
            }
          },
          icon: const Icon(Icons.launch_rounded, size: 18),
          label: const Text('Open'),
        ),
      if (state == ToolState.updateAvailable)
        FilledButton.tonalIcon(
          onPressed: () => _browse(context, tool.page),
          icon: const Icon(Icons.system_update_alt_rounded, size: 18),
          label: const Text('Get the update'),
        ),
      if (state == ToolState.notInstalled || state == ToolState.needsAutocad)
        FilledButton.tonalIcon(
          onPressed: () => _browse(context, tool.page),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Get it'),
        ),
      if (tool.webApp != null)
        OutlinedButton.icon(
          onPressed: () => _browse(context, tool.webApp!),
          icon: const Icon(Icons.language_rounded, size: 18),
          label: const Text('Web app'),
        ),
      if (tool.notes != null)
        TextButton(onPressed: () => _browse(context, tool.notes!), child: const Text('What\'s new')),
      if (tool.install.kind == 'zip' && state == ToolState.notInstalled)
        TextButton(
          onPressed: () async {
            final folder = await getDirectoryPath(confirmButtonText: 'Use this folder');
            if (folder != null) await model.setFolderManagerFolder(folder);
          },
          child: const Text('Already have it? Choose its folder'),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: c.cardSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_iconOf(tool.id), color: c.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tool.name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(tool.platform, style: TextStyle(color: c.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // the status and the versions: side by side, or the versions under it when narrow
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag(state.label, color: tagColor, textColor: tagText, icon: tagIcon),
                Text(
                  versions,
                  style: TextStyle(color: c.ink, fontWeight: FontWeight.w600, fontFeatures: tabular),
                ),
              ],
            ),
            if (installed?.note != null || (state == ToolState.needsAutocad && tool.install.needs != null)) ...[
              const SizedBox(height: 4),
              Text(
                state == ToolState.needsAutocad ? tool.install.needs! : installed!.note!,
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            ],
            for (final p in tool.problems) ...[
              const SizedBox(height: 8),
              Text(
                p,
                style: TextStyle(color: c.muted, fontSize: 12.5, fontStyle: FontStyle.italic),
              ),
            ],
            if (buttons.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: buttons)],
          ],
        ),
      ),
    );
  }
}
