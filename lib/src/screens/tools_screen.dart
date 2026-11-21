// Home: the tools as one list, a row each, with what is installed on this PC, the latest version
// and one button for what to do next (Update, Install, Open); the rest (Web app, What's new,
// Uninstall) is in the row's ⋯ menu. How updates run is in Settings (settings_screen.dart).
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../toolkit/feed.dart';
import '../toolkit/installer.dart';
import '../toolkit/status.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../update/auto_update.dart';
import '../update/update_prefs.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.model, this.auto});
  final ToolkitModel model;

  /// The automatic updates: "Check for updates" updates what is set to Automatic too
  final AutoUpdater? auto;

  Future<void> _check() => auto?.check(self: false) ?? model.refresh();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: PageHeader(
        title: 'Home',
        actions: [
          if (MediaQuery.sizeOf(context).width < 640)
            IconButton(
              tooltip: 'Check for updates',
              onPressed: model.busy ? null : _check,
              icon: const Icon(Icons.refresh_rounded),
            )
          else
            OutlinedButton.icon(
              onPressed: model.busy ? null : _check,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check for updates'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(model: model),
                  if (model.problem != null) ...[
                    const SizedBox(height: 12),
                    Notice(model.problem!, kind: NoticeKind.warning),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < model.tools.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: c.line),
                          ToolRow(tool: model.tools[i], model: model),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    model.installer == null
                        ? 'Look only: the Toolkit shows what is on this PC and what is new. "Get it" opens '
                              'the tool\'s page in your browser.'
                        : 'Each tool is installed with its own official installer, checked by its SHA-256 '
                              'first. A tool that is open is never updated: it is updated once it is closed.',
                    style: TextStyle(color: c.muted, fontSize: 12),
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

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// The line at the top: how many updates, how many installed, when last checked (kept current each minute)
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  headline,
                  style: TextStyle(color: c.ink, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(color: c.muted, fontSize: 12.5, fontFeatures: tabular),
              ),
            ],
          ),
        ),
        if (model.busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

IconData _iconOf(String id) => switch (id) {
  'excel-to-kml' => Icons.public_rounded,
  'roadpro' => Icons.alt_route_rounded,
  'traverse' => Icons.explore_outlined,
  'folder-manager' => Icons.folder_copy_outlined,
  'slope' => Icons.trending_up_rounded,
  'auto-draft' => Icons.architecture_rounded,
  _ => Icons.extension_outlined,
};

/// One tool on its own (RoadPro's page): its row in a panel
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.tool, required this.model});
  final FeedTool tool;
  final ToolkitModel model;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ToolRow(tool: tool, model: model),
  );
}

/// One tool: its icon and name, its status and versions, one button for what to do next, and a
/// ⋯ menu with the rest. Under it while something happens: the progress, then the result.
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.tool, required this.model});
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
    final Color? dot = switch (state) {
      ToolState.upToDate => c.rise,
      ToolState.updateAvailable => c.accent,
      ToolState.unknown => c.muted,
      _ => null,
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
    final canAct = model.installer != null && tool.download != null;

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

    Future<void> open() async {
      if (!await model.open(tool) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tool.name} could not be opened.')));
      }
    }

    Future<void> chooseFolder() async {
      final folder = await getDirectoryPath(confirmButtonText: 'Use this folder');
      if (folder != null) await model.setFolderManagerFolder(folder);
    }

    // the buttons: Update is the one filled button on the page's rows; the others are quiet
    final buttons = <Widget>[
      if (installed?.program != null) OutlinedButton(onPressed: job ? null : open, child: const Text('Open')),
      if (state == ToolState.updateAvailable)
        canAct
            ? FilledButton(onPressed: canInstall ? () => model.install(tool) : null, child: const Text('Update'))
            : FilledButton(onPressed: () => _browse(context, tool.page), child: const Text('Get the update')),
      if (state == ToolState.notInstalled || state == ToolState.needsAutocad)
        canAct
            ? OutlinedButton.icon(
                onPressed: canInstall ? () => model.install(tool) : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Install'),
              )
            : OutlinedButton(onPressed: () => _browse(context, tool.page), child: const Text('Get it')),
    ];
    final more = <PopupMenuEntry<VoidCallback>>[
      if (tool.webApp != null)
        PopupMenuItem(
          value: () => _browse(context, tool.webApp!),
          height: 32,
          child: const _MenuLine(Icons.language_rounded, 'Web app'),
        ),
      if (tool.notes != null)
        PopupMenuItem(
          value: () => _browse(context, tool.notes!),
          height: 32,
          child: const _MenuLine(Icons.article_outlined, 'What\'s new'),
        ),
      if (tool.install.kind == 'zip' && state == ToolState.notInstalled)
        PopupMenuItem(
          value: chooseFolder,
          enabled: !job,
          height: 32,
          child: const _MenuLine(Icons.folder_open_outlined, 'Already have it? Choose its folder'),
        ),
      if (installed != null && installed.found && model.installer != null && uninstallBlock == null) ...[
        const PopupMenuDivider(height: 9),
        PopupMenuItem(
          value: uninstall,
          enabled: !model.jobRunning,
          height: 32,
          child: _MenuLine(Icons.delete_outline_rounded, 'Uninstall', colour: c.fall),
        ),
      ],
    ];
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final b in buttons) ...[b, const SizedBox(width: 6)],
        if (more.isNotEmpty)
          PopupMenuButton<VoidCallback>(
            key: ValueKey('more ${tool.id}'),
            tooltip: 'More',
            position: PopupMenuPosition.under,
            onSelected: (run) => run(),
            itemBuilder: (_) => more,
            child: SizedBox(
              width: Sizes.control,
              height: Sizes.control,
              child: Icon(Icons.more_horiz_rounded, size: 18, color: c.muted),
            ),
          )
        else
          const SizedBox(width: Sizes.control),
      ],
    );

    final name = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.cardSoft,
            borderRadius: BorderRadius.circular(Sizes.radius),
            border: Border.all(color: c.line),
          ),
          child: Icon(_iconOf(tool.id), size: 17, color: c.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tool.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink),
              ),
              Text(
                tool.platform,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
    final status = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tag(state.label, color: dot),
        Text(
          versions,
          style: TextStyle(color: c.ink, fontSize: 12.5, fontFeatures: tabular),
        ),
      ],
    );
    final notes = <Widget>[
      if (installed?.note != null || (state == ToolState.needsAutocad && tool.install.needs != null))
        Text(
          state == ToolState.needsAutocad ? tool.install.needs! : installed!.note!,
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
      if (waitText(model, tool, state) case final wait?) Text(wait, style: TextStyle(color: c.muted, fontSize: 12)),
      // the website's notes on a tool are for the owner; a user sees them only when the download
      // can't be checked
      if (tool.download == null && !model.noFeed)
        for (final p in tool.problems)
          Text(
            p,
            style: TextStyle(color: c.muted, fontSize: 12, fontStyle: FontStyle.italic),
          ),
      if (job)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _JobBar(progress: model.jobProgress),
        )
      else if (result != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Notice(
            result.message,
            kind: result.ok
                ? NoticeKind.success
                : result.blocked
                ? NoticeKind.warning
                : NoticeKind.problem,
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final wide = box.maxWidth >= 760 * scale;
          final under = notes.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 44, top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < notes.length; i++) ...[if (i > 0) const SizedBox(height: 3), notes[i]],
                    ],
                  ),
                );
          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(flex: 4, child: name),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: status),
                    const SizedBox(width: 12),
                    // the same width on every row, so the status column lines up
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 200 * scale),
                      child: actions,
                    ),
                  ],
                ),
                ?under,
              ],
            );
          }
          // narrow: the status, then the buttons, under the name
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              name,
              Padding(padding: const EdgeInsets.only(left: 44, top: 6), child: status),
              ?under,
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A line of a ⋯ menu: its icon and words
class _MenuLine extends StatelessWidget {
  const _MenuLine(this.icon, this.text, {this.colour});
  final IconData icon;
  final String text;
  final Color? colour;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: colour ?? context.colors.muted),
      const SizedBox(width: 10),
      Flexible(
        child: Text(text, style: TextStyle(fontSize: 13, color: colour ?? context.colors.ink)),
      ),
    ],
  );
}

/// What the job on a row is doing: Downloading 42 %, Installing, Checking
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
              style: TextStyle(color: c.ink, fontSize: 12.5, fontWeight: FontWeight.w500, fontFeatures: tabular),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: f, minHeight: 4),
              ),
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

/// Settings → Updates: running in the background, and each installed tool's Automatic or Ask me
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
      builder: (context, _) => Panel(
        title: 'Updates',
        trailing: auto.updating
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8))
            : null,
        description:
            'The Toolkit checks when it opens and every 4 hours while it runs. A tool set to Automatic is '
            'updated as soon as it is closed, and a Windows notification says so.',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              key: const ValueKey('background switch'),
              contentPadding: EdgeInsets.zero,
              value: bg.on,
              onChanged: !bg.known || bg.saving ? null : (v) => bg.setOn(v),
              title: const Text('Start with Windows and keep running in the tray'),
              subtitle: Text(
                bg.on
                    ? 'Closing the window keeps the Toolkit in the tray, so updates go on. Quit it from the tray icon.'
                    : 'Off: updates happen only while the Toolkit is open.',
              ),
            ),
          ),
          if (bg.problem != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Notice(bg.problem!, kind: NoticeKind.warning),
            ),
          for (final t in model.tools)
            if (model.installedOf(t.id)?.found ?? false) _ModeRow(tool: t, model: model),
          if (!model.tools.any((t) => model.installedOf(t.id)?.found ?? false))
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Once a tool is installed, choose here how it is updated.',
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
            ),
        ],
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
        Text(
          tool.name,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.ink),
        ),
        if (tool.install.opensAfterSilentInstall && mode == UpdateMode.automatic)
          Text('When you open it from the Toolkit', style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
    // side by side, or the choice under the name when narrow
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
