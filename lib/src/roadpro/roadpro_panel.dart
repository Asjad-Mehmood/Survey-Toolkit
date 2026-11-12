// RoadPro in the workspace. RoadPro is an AutoCAD plugin: it runs inside AutoCAD, not in the
// Toolkit's window. So its page here gathers what you need around it:
//   - the same card as on Home (installed version, Install / Update),
//   - Start AutoCAD: every AutoCAD, Civil 3D or Map 3D on this PC, started with one press
//     (RoadPro loads by itself at start-up, then RDP starts it),
//   - the commands, searchable; a press copies one to paste in AutoCAD,
//   - the user guide, the shortcut keys sheet and RoadPro Hub.
// The commands and links come from exceltokml.com (/api/toolkit/roadpro), so a new RoadPro version
// needs no new Toolkit; the last copy is kept for when the PC is offline.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/tools_screen.dart' show ToolCard;
import '../toolkit/feed.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'roadpro_pc.dart';

class RoadProCommand {
  const RoadProCommand({required this.short, required this.full, required this.text});
  final String short;
  final String full;
  final String text;
}

/// What /api/toolkit/roadpro gives: the commands and the help links
class RoadProInfo {
  const RoadProInfo({required this.commands, required this.keys, required this.links});

  final List<RoadProCommand> commands;
  final List<(String, String)> keys;

  /// page, guide, shortcuts, whatsNew: only https addresses on exceltokml.com or GitHub
  final Map<String, String> links;

  static RoadProInfo? from(Object? j) {
    if (j is! Map<String, Object?>) return null;
    String? s(Object? v, [int max = 600]) => v is String && v.trim().isNotEmpty && v.length <= max ? v.trim() : null;
    final commands = <RoadProCommand>[];
    final list = j['commands'];
    if (list is List) {
      for (final c in list.take(200)) {
        if (c is! Map) continue;
        final full = s(c['full'], 40), text = s(c['text'], 2000);
        var short = s(c['short'], 20);
        // a command with no short name ("—" on the website) is typed in full
        if (short != null && !RegExp(r'[A-Za-z0-9]').hasMatch(short)) short = full;
        if (short == null || full == null || text == null) continue;
        if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(short) || !RegExp(r'^[A-Z0-9_]+$').hasMatch(full)) continue;
        commands.add(RoadProCommand(short: short, full: full, text: text));
      }
    }
    final keys = <(String, String)>[];
    final k = j['keys'];
    if (k is List) {
      for (final e in k.take(20)) {
        if (e is! Map) continue;
        final key = s(e['key'], 20), text = s(e['text']);
        if (key != null && text != null) keys.add((key, text));
      }
    }
    final links = <String, String>{};
    final l = j['links'];
    if (l is Map) {
      for (final name in const ['page', 'guide', 'shortcuts', 'whatsNew']) {
        final v = l[name];
        if (v is String && isAllowedUrl(v)) links[name] = v;
      }
    }
    if (commands.isEmpty) return null;
    return RoadProInfo(commands: commands, keys: keys, links: links);
  }
}

class RoadProPanel extends StatefulWidget {
  const RoadProPanel({super.key, required this.model, required this.pc});
  final ToolkitModel model;
  final RoadProPc pc;

  static const infoKey = 'roadpro-info';

  @override
  State<RoadProPanel> createState() => _RoadProPanelState();
}

class _RoadProPanelState extends State<RoadProPanel> {
  List<AutocadProduct>? _autocads;
  String? _hub;
  RoadProInfo? _info;
  bool _infoFailed = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _info = RoadProInfo.from(widget.model.store.readJson(RoadProPanel.infoKey));
    unawaited(_look());
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    final autocads = await widget.pc.autocads();
    final hub = await widget.pc.hub();
    if (mounted) {
      setState(() {
        _autocads = autocads;
        _hub = hub;
      });
    }
  }

  Future<void> _load() async {
    try {
      final j = await widget.model.api.call('GET', '/api/toolkit/roadpro');
      final info = RoadProInfo.from(j);
      if (info == null) throw const FormatException();
      widget.model.store.writeJson(RoadProPanel.infoKey, j);
      if (mounted) setState(() => _info = info);
    } catch (_) {
      if (mounted) setState(() => _infoFailed = true);
    }
  }

  FeedTool? get _tool => widget.model.tools.where((t) => t.id == 'roadpro').firstOrNull;
  bool get _installed => widget.model.installedOf('roadpro')?.found ?? false;

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start(AutocadProduct a) async {
    final ok = await widget.pc.start(a.exe);
    if (!mounted) return;
    _say(
      ok
          ? '${a.name} is starting. RoadPro loads by itself; type RDP to begin.'
          : '${a.name} could not be started. Start it from the Start menu instead.',
    );
  }

  Future<void> _openHub() async {
    final hub = _hub;
    if (hub == null) return;
    if (!await widget.pc.start(hub) && mounted) _say('RoadPro Hub could not be opened.');
  }

  Future<void> _browse(String? url) async {
    if (url == null || !isAllowedUrl(url)) return;
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && mounted) {
      _say('The browser could not open $url');
    }
  }

  Future<void> _copy(RoadProCommand c) async {
    await Clipboard.setData(ClipboardData(text: c.short));
    if (mounted) _say('${c.short} copied. Paste it in AutoCAD\'s command line and press Enter.');
  }

  @override
  Widget build(BuildContext context) {
    final tool = _tool;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, box) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final wide = box.maxWidth >= 860 * scale;
                final left = <Widget>[
                  if (tool != null) ToolCard(tool: tool, model: widget.model),
                  const SizedBox(height: 14),
                  _startCard(context),
                  const SizedBox(height: 14),
                  _helpCard(context),
                ];
                final commands = _commandsCard(context);
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...left, const SizedBox(height: 14), commands],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
                    ),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: commands),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _startCard(BuildContext context) {
    final c = context.colors;
    final autocads = _autocads;
    return SectionCard(
      title: 'Start AutoCAD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (autocads == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
            )
          else if (autocads.isEmpty)
            const Notice(
              'AutoCAD was not found on this PC. RoadPro needs full AutoCAD, Civil 3D or Map 3D 2013 or newer '
              '(not AutoCAD LT).',
              kind: NoticeKind.warning,
            )
          else ...[
            if (!_installed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Notice('Install RoadPro first (above): AutoCAD then loads it by itself.'),
              ),
            for (final a in autocads)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Row(
                  icon: Icons.architecture_rounded,
                  title: a.name,
                  detail: a.supported
                      ? (a.year != null ? '${a.year} · ${a.release}' : a.release)
                      : 'Too old for RoadPro',
                  action: FilledButton.icon(
                    key: ValueKey('start ${a.release} ${a.name}'),
                    onPressed: a.supported ? () => _start(a) : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Start'),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'In AutoCAD, type RDP to build a road. RDHELP lists every command.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _helpCard(BuildContext context) {
    final links = _info?.links ?? const {};
    final page = links['page'] ?? _tool?.page;
    return SectionCard(
      title: 'Help',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: links['guide'] == null ? null : () => _browse(links['guide']),
            icon: const Icon(Icons.menu_book_outlined, size: 19),
            label: const Text('User guide'),
          ),
          OutlinedButton.icon(
            onPressed: links['shortcuts'] == null ? null : () => _browse(links['shortcuts']),
            icon: const Icon(Icons.keyboard_outlined, size: 19),
            label: const Text('Shortcut keys'),
          ),
          OutlinedButton.icon(
            onPressed: page == null ? null : () => _browse(page),
            icon: const Icon(Icons.public_rounded, size: 19),
            label: const Text('RoadPro page'),
          ),
          if (_hub != null)
            OutlinedButton.icon(
              onPressed: _openHub,
              icon: const Icon(Icons.dashboard_customize_outlined, size: 19),
              label: const Text('RoadPro Hub'),
            ),
        ],
      ),
    );
  }

  Widget _commandsCard(BuildContext context) {
    final c = context.colors;
    final info = _info;
    final q = _query.trim().toLowerCase();
    final shown = info == null
        ? const <RoadProCommand>[]
        : [
            for (final cmd in info.commands)
              if (q.isEmpty ||
                  cmd.short.toLowerCase().contains(q) ||
                  cmd.full.toLowerCase().contains(q) ||
                  cmd.text.toLowerCase().contains(q))
                cmd,
          ];
    return SectionCard(
      title: 'Commands',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (info == null)
            _infoFailed
                ? const Notice(
                    'The command list can\'t be loaded just now. Check the connection and open this page again.',
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    ),
                  )
          else ...[
            TextField(
              key: const ValueKey('roadpro search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search ${info.commands.length} commands: junction, taper, report…',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Press a command to copy it.', style: TextStyle(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No command matches "$_query".', style: TextStyle(color: c.muted)),
              ),
            for (final cmd in shown)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _copy(cmd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 84),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.cardSoft,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: c.line),
                        ),
                        child: Text(
                          cmd.short,
                          style: TextStyle(fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, color: c.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cmd.full,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted),
                            ),
                            const SizedBox(height: 2),
                            Text(cmd.text, style: TextStyle(color: c.ink, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (info.keys.isNotEmpty) ...[
              Divider(height: 24, color: c.line),
              for (final (key, text) in info.keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          key,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, color: c.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text, style: TextStyle(color: c.muted)),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.detail, required this.action});
  final IconData icon;
  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.ink),
                ),
                Text(detail, style: TextStyle(fontSize: 12.5, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}
