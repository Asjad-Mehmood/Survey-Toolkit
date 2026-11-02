// The Tools page: one card per tool with what is installed on this PC, the latest version and
// what to do (Install, Update, Open, Uninstall), then the Updates section (T5): running in the
// background, and Automatic or Ask me for each tool.
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../brand.dart';
import '../toolkit/feed.dart';
import '../toolkit/installer.dart';
import '../toolkit/status.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../update/auto_update.dart';
import '../update/update_prefs.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.model,
    required this.account,
    required this.settings,
    this.switcher,
    this.auto,
  });
  final ToolkitModel model;
  final Account account;
  final AppSettings settings;

  /// The automatic updates: "Check again" updates what is set to Automatic too
  final AutoUpdater? auto;

  Future<void> _check() => auto?.check(self: false) ?? model.refresh();

  /// The workspace's app grid button, in the header
  final Widget? switcher;

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
            // beside the name when there is room for both
            if (MediaQuery.sizeOf(context).width >= 520) ...[const SizedBox(width: 10), const Tag('Beta')],
          ],
        ),
        actions: [
          ?switcher,
          IconButton(
            tooltip: 'Check again',
            onPressed: model.busy ? null : _check,
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
        onRefresh: _check,
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
                    Notice(
                      model.installer == null
                          ? 'Beta, look only: the Toolkit shows what is on this PC and what is new. "Get it" opens '
                                'the tool\'s page in your browser.'
                          : 'Beta: each tool is installed with its own official installer, checked by its SHA-256 '
                                'first. A tool that is open is never updated: it is updated once it is closed.',
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
                    if (auto != null && model.installer != null) ...[
                      const SizedBox(height: 18),
                      UpdatesSection(model: model, auto: auto!),
                    ],
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

    final job = model.jobTool == tool.id;
    final result = model.results[tool.id];
    final canInstall = model.canInstall(tool);
    final uninstallBlock = model.cannotUninstall(tool);

    Future<void> uninstall() async {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Uninstall ${tool.name}?'),
          content: Text(
            tool.install.kind == 'installer'
                ? '${tool.name} is removed with its own uninstaller, the same as from Windows Settings → Apps.'
                : tool.install.kind == 'zip'
                ? 'The program files are removed. Your settings file is kept, so a new install remembers them.'
                : 'RoadPro is removed from AutoCAD. Roads already drawn stay in your drawings.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Uninstall')),
          ],
        ),
      );
      if (yes == true) await model.uninstall(tool);
    }

    final buttons = <Widget>[
      if (installed?.program != null)
        FilledButton.icon(
          onPressed: job
              ? null
              : () async {
                  if (!await model.open(tool) && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('${tool.name} could not be opened.')));
                  }
                },
          icon: const Icon(Icons.launch_rounded, size: 18),
          label: const Text('Open'),
        ),
      if (state == ToolState.updateAvailable)
        if (tool.download != null && model.installer != null)
          FilledButton.tonalIcon(
            onPressed: canInstall ? () => model.install(tool) : null,
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: const Text('Update'),
          )
        else
          FilledButton.tonalIcon(
            onPressed: () => _browse(context, tool.page),
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: const Text('Get the update'),
          ),
      if (state == ToolState.notInstalled || state == ToolState.needsAutocad)
        if (tool.download != null && model.installer != null)
          FilledButton.tonalIcon(
            onPressed: canInstall ? () => model.install(tool) : null,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Install'),
          )
        else
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
          onPressed: job
              ? null
              : () async {
                  final folder = await getDirectoryPath(confirmButtonText: 'Use this folder');
                  if (folder != null) await model.setFolderManagerFolder(folder);
                },
          child: const Text('Already have it? Choose its folder'),
        ),
      if (installed != null && installed.found && model.installer != null && uninstallBlock == null)
        TextButton(onPressed: model.jobRunning ? null : uninstall, child: const Text('Uninstall')),
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
            if (waitText(model, tool, state) case final wait?) ...[
              const SizedBox(height: 4),
              Text(wait, style: TextStyle(color: c.muted, fontSize: 13)),
            ],
            // the website's notes on a tool are for the owner; a user sees them only when the download
            // can't be checked
            if (tool.download == null && !model.noFeed)
              for (final p in tool.problems) ...[
                const SizedBox(height: 8),
                Text(
                  p,
                  style: TextStyle(color: c.muted, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ],
            if (job) ...[
              const SizedBox(height: 14),
              _JobBar(progress: model.jobProgress),
            ] else if (result != null) ...[
              const SizedBox(height: 12),
              Notice(
                result.message,
                kind: result.ok
                    ? NoticeKind.success
                    : result.blocked
                    ? NoticeKind.warning
                    : NoticeKind.problem,
              ),
            ],
            if (buttons.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: buttons)],
          ],
        ),
      ),
    );
  }
}

/// What the job on a card is doing: Downloading 42 %, Installing, Checking
class _JobBar extends StatelessWidget {
  const _JobBar({required this.progress});
  final JobProgress? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = progress?.step ?? 'Starting';
    final f = progress?.fraction;
    return Semantics(
      liveRegion: true,
      label: f == null ? '$step…' : '$step ${(f * 100).round()} %',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              f == null ? '$step…' : '$step… ${(f * 100).round()} %',
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w600, fontFeatures: tabular),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: f, minHeight: 6, color: c.accent, backgroundColor: c.cardSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under an update that is set to Automatic: when it will happen
String? waitText(ToolkitModel model, FeedTool tool, ToolState state) {
  if (model.installer == null || state != ToolState.updateAvailable || model.jobTool == tool.id) return null;
  if (model.updates.modeOf(tool.id) != UpdateMode.automatic || tool.download == null) return null;
  return tool.install.opensAfterSilentInstall
      ? 'Updates by itself the next time you open it from the Toolkit.'
      : 'Updates by itself when it isn\'t open.';
}

/// Running in the background, and each tool's Automatic or Ask me
class UpdatesSection extends StatelessWidget {
  const UpdatesSection({super.key, required this.model, required this.auto});
  final ToolkitModel model;
  final AutoUpdater auto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = auto.background;
    return ListenableBuilder(
      listenable: Listenable.merge([bg, model.updates, auto]),
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: c.ink),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Updates', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
                  ),
                  if (auto.updating)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'The Toolkit checks when it opens and every 4 hours while it runs. A tool set to Automatic is '
                'updated as soon as it is closed, and a Windows notification says so.',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                key: const ValueKey('background switch'),
                contentPadding: EdgeInsets.zero,
                value: bg.on,
                onChanged: !bg.known || bg.saving ? null : (v) => bg.setOn(v),
                title: const Text(
                  'Start with Windows and keep running in the tray',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  bg.on
                      ? 'Closing the window keeps the Toolkit in the tray, so updates go on. Quit it from the tray icon.'
                      : 'Off: updates happen only while the Toolkit is open.',
                ),
              ),
              if (bg.problem != null) Notice(bg.problem!, kind: NoticeKind.warning),
              Divider(color: c.line, height: 20),
              for (final t in model.tools)
                if (model.installedOf(t.id)?.found ?? false) _ModeRow(tool: t, model: model),
              if (!model.tools.any((t) => model.installedOf(t.id)?.found ?? false))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Once a tool is installed, choose here how it is updated.',
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.tool, required this.model});
  final FeedTool tool;
  final ToolkitModel model;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mode = model.updates.modeOf(tool.id);
    final picker = SegmentedButton<UpdateMode>(
      key: ValueKey('mode ${tool.id}'),
      showSelectedIcon: false,
      segments: [for (final m in UpdateMode.values) ButtonSegment(value: m, label: Text(m.label))],
      selected: {mode},
      onSelectionChanged: (s) => model.updates.setMode(tool.id, s.first),
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tool.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (tool.install.opensAfterSilentInstall && mode == UpdateMode.automatic)
          Text('When you open it from the Toolkit', style: TextStyle(color: c.muted, fontSize: 12.5)),
      ],
    );
    // side by side, or the choice under the name when narrow
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [name, picker],
        ),
      ),
    );
  }
}
