// Home: a top bar (search, Check for updates, notifications, light or dark), a welcome banner
// with the survey scene and three figures, the tools as cards (status, versions, the buttons for
// what to do next, a ⋯ menu for Web app, What's new and Uninstall), and beside them the updates
// waiting (Update all) and Recent activity. How updates run is in Settings (settings_screen.dart).
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'home_hero.dart';

/// Which tools Home lists
enum _Show { all, installed, updates }

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.model, this.auto, this.userName, this.settings});
  final ToolkitModel model;

  /// The automatic updates: "Check for updates" updates what is set to Automatic too
  final AutoUpdater? auto;

  /// For the greeting
  final String? userName;

  /// For the light / dark button in the top bar
  final AppSettings? settings;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  _Show _show = _Show.all;
  String _search = '';
  Timer? _timer;

  ToolkitModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    // "checked 2 min ago" and the activity times stay current
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() => widget.auto?.check(self: false) ?? model.refresh();

  bool _isInstalled(FeedTool t) => model.installedOf(t.id)?.found ?? false;

  /// Every tool with an update the Toolkit can install, one after the other
  Future<void> _updateAll() async {
    for (final t in model.tools) {
      if (model.stateOfTool(t) == ToolState.updateAvailable && model.canInstall(t)) await model.install(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final updates = model.countIn(ToolState.updateAvailable);
    final q = _search.trim().toLowerCase();
    final tools = [
      for (final t in model.tools)
        if ((_show == _Show.all ||
                (_show == _Show.installed && _isInstalled(t)) ||
                (_show == _Show.updates && model.stateOfTool(t) == ToolState.updateAvailable)) &&
            (q.isEmpty || t.name.toLowerCase().contains(q) || t.platform.toLowerCase().contains(q)))
          t,
    ];

    final toolsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded, size: 20, color: highlightColour(Theme.of(context).brightness)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Your tools',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.2),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_Show>(
                key: const ValueKey('show'),
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: _Show.all, label: Text('All')),
                  const ButtonSegment(value: _Show.installed, label: Text('Installed')),
                  ButtonSegment(value: _Show.updates, label: Text(updates > 0 ? 'Updates ($updates)' : 'Updates')),
                ],
                selected: {_show},
                onSelectionChanged: (v) => setState(() => _show = v.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (tools.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              q.isNotEmpty
                  ? 'No tool matches "$_search".'
                  : _show == _Show.updates
                  ? 'Everything is up to date.'
                  : 'Nothing installed yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final columns = box.maxWidth >= 1040 * scale
                  ? 3
                  : box.maxWidth >= 600 * scale
                  ? 2
                  : 1;
              const gap = 18.0;
              final width = (box.maxWidth - gap * (columns - 1)) / columns;
              // a row of cards is as tall as its tallest, so the buttons line up
              return Column(
                children: [
                  for (var i = 0; i < tools.length; i += columns) ...[
                    if (i > 0) const SizedBox(height: gap),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var k = i; k < i + columns; k++) ...[
                            if (k > i) const SizedBox(width: gap),
                            SizedBox(
                              width: width,
                              child: k < tools.length ? ToolCard(tool: tools[k], model: model) : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );

    final side = [
      _UpdatesCard(
        model: model,
        onUpdateAll: model.jobRunning ? null : _updateAll,
        onCheck: model.busy ? null : _check,
      ),
      const SizedBox(height: 18),
      _ActivityCard(model: model),
    ];

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            onSearch: (v) => setState(() => _search = v),
            onCheck: model.busy ? null : _check,
            busy: model.busy,
            settings: widget.settings,
            model: model,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(model: model, name: widget.userName),
                        if (model.problem != null) ...[
                          const SizedBox(height: 14),
                          Notice(model.problem!, kind: NoticeKind.warning),
                        ],
                        const SizedBox(height: 26),
                        LayoutBuilder(
                          builder: (context, box) {
                            final scale = MediaQuery.textScalerOf(context).scale(1);
                            if (box.maxWidth >= 1020 * scale) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: toolsSection),
                                  const SizedBox(width: 22),
                                  SizedBox(
                                    width: 330,
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: side),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [toolsSection, const SizedBox(height: 24), ...side],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 15, color: c.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                model.installer == null
                                    ? 'Look only: the Toolkit shows what is on this PC and what is new. "Get it" opens '
                                          'the tool\'s page in your browser.'
                                    : 'Each tool is installed with its own official installer, checked by its SHA-256 '
                                          'first. A tool that is open is never updated: it is updated once it is closed.',
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// Home's top bar: search, Check for updates, what happened lately, light or dark
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSearch,
    required this.onCheck,
    required this.busy,
    required this.settings,
    required this.model,
  });
  final ValueChanged<String> onSearch;
  final VoidCallback? onCheck;
  final bool busy;
  final AppSettings? settings;
  final ToolkitModel model;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final updates = model.countIn(ToolState.updateAvailable);
    final round = BorderRadius.circular(99);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  key: const ValueKey('search'),
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: narrow ? 'Search tools…' : 'Search tools… (e.g. Excel to KML)',
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.muted),
                    prefixIconConstraints: const BoxConstraints(minWidth: 42),
                    fillColor: c.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: round,
                      borderSide: BorderSide(color: c.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: round,
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: round,
                      borderSide: BorderSide(color: highlightColour(brightness), width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (narrow)
            IconButton(tooltip: 'Check for updates', onPressed: onCheck, icon: const Icon(Icons.refresh_rounded))
          else
            OutlinedButton.icon(
              onPressed: onCheck,
              icon: Icon(Icons.sync_rounded, color: highlightColour(brightness)),
              label: const Text('Check for updates'),
            ),
          const SizedBox(width: 6),
          // what happened lately, with the number of updates waiting
          PopupMenuButton<void>(
            key: const ValueKey('notifications'),
            tooltip: 'Notifications',
            position: PopupMenuPosition.under,
            itemBuilder: (context) {
              final items = _activityItems(model).take(6).toList();
              return [
                if (items.isEmpty)
                  const PopupMenuItem<void>(enabled: false, child: Text('Nothing new.'))
                else
                  for (final a in items)
                    PopupMenuItem<void>(
                      enabled: false,
                      height: 44,
                      child: SizedBox(width: 280, child: _ActivityLine(item: a, compact: true)),
                    ),
              ];
            },
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 20, color: c.ink),
                  if (updates > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.fall,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (settings != null)
            IconButton(
              tooltip: brightness == Brightness.light ? 'Dark mode' : 'Light mode',
              onPressed: () => settings!.cycleTheme(brightness),
              icon: Icon(brightness == Brightness.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
            ),
        ],
      ),
    );
  }
}

/// The top of Home: a welcome, the Toolkit's name and three figures on the left, on a light blue
/// gradient; the survey scene on the right half, fading in, never behind the words
class _Hero extends StatelessWidget {
  const _Hero({required this.model, required this.name});
  final ToolkitModel model;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final updates = model.countIn(ToolState.updateAvailable);
    final upToDate = model.countIn(ToolState.upToDate);
    final first = (name ?? '').split(' ').first;

    Widget figure(String label, String value, IconData icon, String id) => Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: dark ? 0.75 : 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? c.line : Colors.white),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1D3F8F).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(id: id, icon: icon, size: 34),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.ink, fontFeatures: tabular),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first.isEmpty ? 'Welcome back' : 'Welcome back, $first',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted),
        ),
        const SizedBox(height: 6),
        Text(
          appName,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: dark ? Colors.white : const Color(0xFF0B1A3A),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text('Every survey tool in one place, always up to date.', style: TextStyle(fontSize: 14, color: c.muted)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            figure('Total tools', '${model.tools.length}', Icons.apps_rounded, 'traverse'),
            figure('Updates', '$updates', Icons.system_update_alt_rounded, 'folder-manager'),
            figure('Up to date', '$upToDate', Icons.check_rounded, 'excel-to-kml'),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Sizes.panelRadius + 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xFF172036), const Color(0xFF1B2A4D)]
                : [const Color(0xFFF7FAFF), const Color(0xFFE6EEFC)],
          ),
          border: Border.all(color: dark ? const Color(0xFF26314A) : const Color(0xFFDCE5F7)),
          borderRadius: BorderRadius.circular(Sizes.panelRadius + 4),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // wide: the words on the left half, the scene on the right; narrow: the words alone
            final wide = box.maxWidth >= 820 * MediaQuery.textScalerOf(context).scale(1);
            return Stack(
              children: [
                // the scene on the right, fading in, never behind the words
                if (wide) Positioned.fill(child: SurveyScene(dark: dark)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
                  child: wide
                      ? ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
                          child: words,
                        )
                      : words,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The card beside the tools: the updates waiting and Update all, or that all is well
class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({required this.model, required this.onUpdateAll, required this.onCheck});
  final ToolkitModel model;
  final VoidCallback? onUpdateAll;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final waiting = [
      for (final t in model.tools)
        if (model.stateOfTool(t) == ToolState.updateAvailable) t,
    ];
    final upToDate = model.countIn(ToolState.upToDate);
    final installed = upToDate + waiting.length + model.countIn(ToolState.unknown);
    final headline = model.busy && model.checkedAt == null
        ? 'Checking your tools…'
        : model.noFeed
        ? 'Can\'t reach surveyxdigital.com yet'
        : waiting.isNotEmpty
        ? '${waiting.length} ${waiting.length == 1 ? 'update' : 'updates'} available'
        : installed == 0
        ? 'None of the tools is installed yet'
        : 'Everything installed is up to date';
    final detail = [
      '$installed of ${model.tools.length} installed',
      if (model.checkedAt != null) 'checked ${_ago(model.checkedAt!)}${model.fromKept ? ' (offline)' : ''}',
    ].join(' · ');
    final canUpdate = waiting.any((t) => model.installer != null && t.download != null);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Sizes.panelRadius),
        color: c.card,
        border: Border.all(color: c.line),
        boxShadow: softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(id: 'toolkit', icon: Icons.rocket_launch_rounded, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        headline,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (waiting.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final t in waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    AppIcon(id: t.id, icon: _iconOf(t.id), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${t.name}  ${model.installedOf(t.id)?.version ?? ''} → ${t.version ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.ink, fontFeatures: tabular),
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            const SizedBox(height: 6),
          const SizedBox(height: 10),
          if (waiting.isNotEmpty && canUpdate)
            FilledButton.icon(
              key: const ValueKey('update all'),
              onPressed: onUpdateAll,
              icon: const Icon(Icons.system_update_alt_rounded),
              label: const Text('Update all'),
            )
          else
            FilledButton.icon(onPressed: onCheck, icon: const Icon(Icons.sync_rounded), label: const Text('Check now')),
        ],
      ),
    );
  }
}

/// One line of Recent activity
@immutable
class _Activity {
  const _Activity(this.toolId, this.name, this.text, this.icon, this.colour, this.at);
  final String toolId;
  final String name;
  final String text;
  final IconData icon;
  final Color colour;
  final DateTime? at;
}

/// What happened lately: the updates waiting, then what the Toolkit did on this PC
List<_Activity> _activityItems(ToolkitModel model) => [
  for (final t in model.tools)
    if (model.stateOfTool(t) == ToolState.updateAvailable)
      _Activity(
        t.id,
        t.name,
        'Update available: ${t.version}',
        Icons.arrow_upward_rounded,
        const Color(0xFF16A34A),
        model.checkedAt,
      ),
  for (final a in model.activity)
    switch (a.action) {
      'installed' => _Activity(
        a.toolId,
        a.name,
        'Installed ${a.version ?? ''}'.trim(),
        Icons.check_rounded,
        const Color(0xFF2563EB),
        a.at,
      ),
      'updated' => _Activity(
        a.toolId,
        a.name,
        'Updated to ${a.version ?? ''}'.trim(),
        Icons.upgrade_rounded,
        const Color(0xFF7C3AED),
        a.at,
      ),
      'uninstalled' => _Activity(a.toolId, a.name, 'Uninstalled', Icons.remove_rounded, const Color(0xFF64748B), a.at),
      _ => _Activity(a.toolId, a.name, 'Didn\'t finish', Icons.priority_high_rounded, const Color(0xFFDC2626), a.at),
    },
];

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.item, this.compact = false});
  final _Activity item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = compact ? 26.0 : 32.0;
    final when = item.at == null ? null : _ago(item.at!);
    // narrow: the time goes under the words instead of beside them
    return LayoutBuilder(
      builder: (context, box) {
        final beside = box.maxWidth >= 260 * MediaQuery.textScalerOf(context).scale(1);
        return Row(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: item.colour.withValues(alpha: 0.11)),
              child: Icon(item.icon, size: compact ? 14 : 17, color: item.colour),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                  ),
                  Text(
                    beside || when == null ? item.text : '${item.text} · $when',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ),
            ),
            if (beside && when != null) ...[
              const SizedBox(width: 8),
              Text(when, style: TextStyle(fontSize: 11.5, color: c.muted)),
            ],
          ],
        );
      },
    );
  }
}

/// Recent activity, beside the tools
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.model});
  final ToolkitModel model;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _activityItems(model).take(6).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Sizes.panelRadius),
        border: Border.all(color: c.line),
        boxShadow: softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: highlightColour(Theme.of(context).brightness)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Recent activity',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Installs and updates made by the Toolkit show here.',
                style: TextStyle(fontSize: 12.5, color: c.muted),
              ),
            )
          else
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ActivityLine(item: a),
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
  'auto-draft' => Icons.architecture_rounded,
  _ => Icons.extension_outlined,
};

/// One tool as a raised card (Home and RoadPro's page)
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.tool, required this.model});
  final FeedTool tool;
  final ToolkitModel model;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(Sizes.panelRadius),
      border: Border.all(color: context.colors.line),
      boxShadow: softShadow(context),
    ),
    child: ToolRow(tool: tool, model: model),
  );
}

/// One tool: its icon and name, its status and versions, the buttons for what to do next, and a
/// ⋯ menu with the rest. While something happens: the progress, then the result.
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
    final status = Tag(state.label, color: dot);
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
        _JobBar(progress: model.jobProgress)
      else if (result != null)
        Notice(
          result.message,
          kind: result.ok
              ? NoticeKind.success
              : result.blocked
              ? NoticeKind.warning
              : NoticeKind.problem,
        ),
    ];

    // a card: the icon, name and status; the versions and notes; the buttons at its foot
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(id: tool.id, icon: _iconOf(tool.id), size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          tool.platform,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 3,
                    child: Align(alignment: Alignment.topRight, child: status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                versions,
                style: TextStyle(color: c.ink, fontSize: 12.5, fontFeatures: tabular),
              ),
              for (final n in notes) ...[const SizedBox(height: 6), n],
              const SizedBox(height: 16),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final b in buttons) ...[b, const SizedBox(width: 8)],
                      ],
                    ),
                  ),
                ),
              ),
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
                ),
            ],
          ),
        ],
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
