// The workspace: like the Microsoft 365 app, one window with a sidebar. Home is the Tools page;
// Excel to KML, Traverse & Level and Slope Calculator open inside the window, signed in already
// (the website's single-use sign-in handover), Project Folder Manager runs inside it as part of
// the Toolkit, and RoadPro has its own page (lib/src/roadpro: it runs inside AutoCAD). Each stays open in the background when you switch, like tabs. Like Google's apps,
// the grid button in the header jumps to any of them too. Ctrl+1 is Home, Ctrl+2 to Ctrl+6 the apps.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_folder_manager/project_folder_manager.dart' show FolderManagerView;
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../brand.dart';
import '../roadpro/roadpro_panel.dart';
import '../roadpro/roadpro_pc.dart';
import '../screens/tools_screen.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import '../update/auto_update.dart';
import 'app_view.dart';
import 'apps.dart';

/// Project Folder Manager itself, with this user's settings (the same as the separate program's)
Widget folderManagerView(WorkspaceApp app) => const FolderManagerView();

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.account,
    required this.model,
    required this.settings,
    required this.views,
    this.native = folderManagerView,
    this.roadproPc,
    this.auto,
  });
  final Account account;
  final ToolkitModel model;
  final AppSettings settings;
  final AppViewFactory views;
  final NativeViewFactory native;

  /// AutoCAD and RoadPro Hub on this PC, for the RoadPro page (Windows' unless given)
  final RoadProPc? roadproPc;

  /// The automatic updates, for the Tools page's Updates section
  final AutoUpdater? auto;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  static const _lastKey = 'workspace-last';

  /// 0 is Home, then [workspaceApps]
  int _page = 0;

  /// The apps opened so far: they stay running when another page is shown
  final _open = <String, AppViewHandle>{};

  /// The apps of the Toolkit's own (Project Folder Manager) opened so far: made once, kept running
  final _nativeOpen = <String, Widget>{};

  @override
  void initState() {
    super.initState();
    // back where the user was last time
    final last = workspaceApps.indexWhere((a) => a.id == widget.model.store.read(_lastKey));
    if (last >= 0) _show(last + 1, remember: false);
  }

  @override
  void dispose() {
    // signed out: each window forgets its sign-in before it goes
    final signedOut = !widget.account.signedIn;
    for (final h in _open.values) {
      if (signedOut) {
        unawaited(h.forget().whenComplete(h.dispose));
      } else {
        h.dispose();
      }
    }
    super.dispose();
  }

  Future<String> _startOf(WorkspaceApp app) async {
    final url = await widget.account.handoffUrl(app.path);
    return url ?? '$apiBase${app.path}';
  }

  void _show(int page, {bool remember = true}) {
    if (page > 0) {
      final app = workspaceApps[page - 1];
      if (app.native) {
        _nativeOpen.putIfAbsent(
          app.id,
          () => app.id == 'roadpro'
              ? RoadProPanel(model: widget.model, pc: widget.roadproPc ?? WindowsRoadProPc())
              : widget.native(app),
        );
      } else {
        _open.putIfAbsent(app.id, () => widget.views(app, () => _startOf(app)));
      }
    }
    if (remember) widget.model.store.write(_lastKey, page == 0 ? 'home' : workspaceApps[page - 1].id);
    setState(() => _page = page);
  }

  Widget _switcher() => _AppGridButton(current: _page, onPick: _show);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final pages = <Widget>[
      ToolsScreen(
        model: widget.model,
        account: widget.account,
        settings: widget.settings,
        switcher: _switcher(),
        auto: widget.auto,
      ),
      for (final app in workspaceApps)
        if (app.native)
          _nativeOpen[app.id] == null
              ? const SizedBox.shrink()
              : _NativePanel(app: app, view: _nativeOpen[app.id]!, switcher: _switcher())
        else
          _open[app.id] == null
              ? const SizedBox.shrink()
              : _AppPanel(app: app, view: _open[app.id]!, model: widget.model, switcher: _switcher()),
    ];
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i <= workspaceApps.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _show(i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(page: _page, wide: wide, onPick: _show),
              VerticalDivider(width: 1, color: c.line),
              Expanded(
                child: IndexedStack(index: _page, sizing: StackFit.expand, children: pages),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page, required this.wide, required this.onPick});
  final int page;
  final bool wide;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(int i, IconData icon, String label, String tooltip) {
      final on = page == i;
      return Tooltip(
        message: '$tooltip  (Ctrl+${i + 1})',
        child: Semantics(
          selected: on,
          button: true,
          label: tooltip,
          child: InkWell(
            key: ValueKey('workspace $label'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => onPick(i),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 32,
                      decoration: BoxDecoration(
                        color: on ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Icon(icon, size: 22, color: on ? c.onAccent : c.ink),
                    ),
                    if (wide) ...[
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                          color: on ? c.ink : c.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: wide ? 92 : 68,
      color: c.card,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/brand/icon-512.png', width: 36, height: 36, excludeFromSemantics: true),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: [
                  item(0, Icons.space_dashboard_outlined, 'Home', 'Home: all tools'),
                  const SizedBox(height: 4),
                  for (var i = 0; i < workspaceApps.length; i++) ...[
                    item(i + 1, workspaceApps[i].icon, workspaceApps[i].short, workspaceApps[i].name),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Google-style grid of apps in the header
class _AppGridButton extends StatelessWidget {
  const _AppGridButton({required this.current, required this.onPick});
  final int current;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Switch app',
    icon: const Icon(Icons.apps_rounded),
    onPressed: () async {
      // a panel under the button, like Google's app grid
      final box = context.findRenderObject()! as RenderBox;
      final below = box.localToGlobal(Offset(0, box.size.height));
      final right = MediaQuery.sizeOf(context).width - below.dx - box.size.width;
      final picked = await showGeneralDialog<int>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close the app grid',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, _, _) => SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(top: below.dy + 4, right: right.clamp(8, double.infinity).toDouble()),
              child: Material(
                elevation: 8,
                color: context.colors.card,
                borderRadius: BorderRadius.circular(18),
                child: _AppGrid(current: current),
              ),
            ),
          ),
        ),
        transitionBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
      );
      if (picked != null) onPick(picked);
    },
  );
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile(int i, IconData icon, String name) => SizedBox(
      width: 140,
      child: InkWell(
        key: ValueKey('grid $name'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: i == current ? c.cardSoft : null, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: BrandColors.navy, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: BrandColors.gold),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      width: 304,
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          tile(0, Icons.space_dashboard_outlined, 'Home'),
          for (var i = 0; i < workspaceApps.length; i++) tile(i + 1, workspaceApps[i].icon, workspaceApps[i].name),
        ],
      ),
    );
  }
}

/// A program that is part of the Toolkit (Project Folder Manager): a slim header like the web apps,
/// then the program itself, with its own top bar, keys and settings (the same as the separate
/// program's, so both show the same project folders).
class _NativePanel extends StatelessWidget {
  const _NativePanel({required this.app, required this.view, required this.switcher});
  final WorkspaceApp app;
  final Widget view;
  final Widget? switcher;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 48,
        titleSpacing: 12,
        title: Row(
          children: [
            Icon(app.icon, color: c.ink),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                app.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [?switcher, const SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.line),
        ),
      ),
      body: view,
    );
  }
}

/// One app inside the window: its toolbar and its page
class _AppPanel extends StatelessWidget {
  const _AppPanel({required this.app, required this.view, required this.model, required this.switcher});
  final WorkspaceApp app;
  final AppViewHandle view;
  final ToolkitModel? model;
  final Widget? switcher;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final model = this.model;
    final tool = model?.tools.where((t) => t.id == app.toolId).firstOrNull;
    final installed = tool == null ? null : model!.installedOf(tool.id);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 12,
        title: Row(
          children: [
            Icon(app.icon, color: c.ink),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                app.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: view.state,
            builder: (context, s, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.loading && s.problem == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                  ),
                IconButton(
                  tooltip: 'Back',
                  onPressed: s.canGoBack ? view.back : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(tooltip: 'Reload', onPressed: view.reload, icon: const Icon(Icons.refresh_rounded)),
                IconButton(
                  tooltip: 'Open in your browser',
                  onPressed: () => launchUrl(Uri.parse('$websiteUrl${app.path}'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
          ),
          if (tool != null && installed?.program != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (model!.updatesOnOpen(tool)) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Updating ${tool.name} to ${tool.version} before it opens…')),
                    );
                  }
                  if (!await model.open(tool)) {
                    messenger.showSnackBar(SnackBar(content: Text('${tool.name} could not be opened.')));
                  }
                },
                icon: const Icon(Icons.desktop_windows_outlined, size: 18),
                label: const Text('Windows app'),
              ),
            ),
          ?switcher,
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.line),
        ),
      ),
      body: view.build(context),
    );
  }
}

/// For the Windows test (`SurveyToolkit.exe --preview=slope`): one web app inside the Toolkit's
/// window as the workspace shows it, without a sign-in (the app shows its own). Nothing else of the
/// Toolkit is reachable from it.
class WorkspacePreview extends StatefulWidget {
  const WorkspacePreview({super.key, required this.appId, this.views = webView2Factory, this.url});
  final String appId;
  final AppViewFactory views;

  /// For the Windows tests (`--preview-url=http://localhost:…`): this page
  /// instead of the app's own, in the same window
  final String? url;

  @override
  State<WorkspacePreview> createState() => _WorkspacePreviewState();
}

class _WorkspacePreviewState extends State<WorkspacePreview> {
  late final WorkspaceApp _app = workspaceApps.firstWhere(
    (a) => a.id == widget.appId,
    orElse: () => workspaceApps.last,
  );
  late final AppViewHandle? _view = _app.native
      ? null
      : widget.views(_app, () async => widget.url ?? '$apiBase${_app.path}');

  @override
  void dispose() {
    _view?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: Row(
        children: [
          _Sidebar(page: workspaceApps.indexOf(_app) + 1, wide: true, onPick: (_) {}),
          const VerticalDivider(width: 1),
          Expanded(
            child: _app.native
                ? _NativePanel(app: _app, view: folderManagerView(_app), switcher: null)
                : _AppPanel(app: _app, view: _view!, model: null, switcher: null),
          ),
        ],
      ),
    ),
  );
}
