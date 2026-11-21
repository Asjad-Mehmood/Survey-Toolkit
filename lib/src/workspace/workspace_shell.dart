// The workspace: one window with a sidebar, like a Windows 11 program. Home is the Tools page;
// Excel to KML, Traverse & Level and Slope Calculator open inside the window, signed in already
// (the website's single-use sign-in handover), Project Folder Manager runs inside it as part of
// the Toolkit, and RoadPro has its own page (lib/src/roadpro: it runs inside AutoCAD). Each stays
// open in the background when you switch, like tabs. Settings and the account are at the foot of
// the sidebar. Ctrl+1 is Home, Ctrl+2 to Ctrl+6 the apps, Ctrl+, Settings.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_folder_manager/project_folder_manager.dart' show FolderManagerView;
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../brand.dart';
import '../roadpro/roadpro_panel.dart';
import '../roadpro/roadpro_pc.dart';
import '../screens/settings_screen.dart';
import '../screens/tools_screen.dart';
import '../toolkit/toolkit_model.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
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
    if (page > 0 && page <= workspaceApps.length) {
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
    if (remember && page <= workspaceApps.length) {
      widget.model.store.write(_lastKey, page == 0 ? 'home' : workspaceApps[page - 1].id);
    }
    setState(() => _page = page);
  }

  /// The page after the apps
  static final _settingsPage = workspaceApps.length + 1;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = <Widget>[
      ToolsScreen(model: widget.model, auto: widget.auto, userName: widget.account.user?.display),
      for (final app in workspaceApps)
        if (app.native)
          _nativeOpen[app.id] == null ? const SizedBox.shrink() : _NativePanel(app: app, view: _nativeOpen[app.id]!)
        else
          _open[app.id] == null
              ? const SizedBox.shrink()
              : _AppPanel(app: app, view: _open[app.id]!, model: widget.model),
      SettingsScreen(model: widget.model, account: widget.account, settings: widget.settings, auto: widget.auto),
    ];
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i <= workspaceApps.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _show(i),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _show(_settingsPage),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(page: _page, wide: wide, onPick: _show, account: widget.account, settingsPage: _settingsPage),
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

/// The sidebar: the Toolkit's name, Home and the apps, and at its foot Settings and the account.
/// Narrow windows show the icons only.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.page,
    required this.wide,
    required this.onPick,
    required this.settingsPage,
    this.account,
  });
  final int page;
  final bool wide;
  final void Function(int) onPick;
  final int settingsPage;

  /// The signed-in account, at the foot (none in the Windows test's preview)
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: wide ? 236 : 60,
      color: c.cardSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: Sizes.header,
            padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 0),
            child: Row(
              mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset('assets/brand/icon-512.png', width: 26, height: 26, excludeFromSemantics: true),
                ),
                if (wide) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      appName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  label: 'Home',
                  name: 'Home',
                  icon: Icons.home_outlined,
                  on: page == 0,
                  wide: wide,
                  shortcut: 'Ctrl+1',
                  onTap: () => onPick(0),
                ),
                if (wide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                    child: Text(
                      'Apps',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.muted),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                for (var i = 0; i < workspaceApps.length; i++)
                  _NavItem(
                    label: workspaceApps[i].short,
                    name: workspaceApps[i].name,
                    icon: workspaceApps[i].icon,
                    appId: workspaceApps[i].id,
                    on: page == i + 1,
                    wide: wide,
                    shortcut: 'Ctrl+${i + 2}',
                    onTap: () => onPick(i + 1),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.line),
          const SizedBox(height: 6),
          _NavItem(
            label: 'Settings',
            name: 'Settings',
            icon: Icons.settings_outlined,
            on: page == settingsPage,
            wide: wide,
            shortcut: 'Ctrl+,',
            onTap: () => onPick(settingsPage),
          ),
          if (account?.user case final user?)
            _AccountTile(account: account!, name: user.display, email: user.email, wide: wide),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// One line of the sidebar: a quiet hover, and a navy bar and tint on the page that is showing
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.name,
    required this.icon,
    required this.on,
    required this.wide,
    required this.shortcut,
    required this.onTap,
    this.appId,
  });

  /// An app's id: its icon is drawn in the app's own colours
  final String? appId;

  /// The short name, also the test key ("workspace Slope")
  final String label;

  /// What the sidebar shows when wide
  final String name;
  final IconData icon;
  final bool on;
  final bool wide;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final action = actionColour(Theme.of(context).brightness);
    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Semantics(
        selected: on,
        button: true,
        label: name,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: on ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(Sizes.radius),
            boxShadow: on ? softShadow(context) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('workspace $label'),
              borderRadius: BorderRadius.circular(Sizes.radius),
              onTap: onTap,
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Row(
                    mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      // the bar on the left of the page that is showing, as in Windows 11
                      if (wide)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 3,
                          height: on ? 16 : 0,
                          margin: const EdgeInsets.only(right: 9),
                          decoration: BoxDecoration(color: action, borderRadius: BorderRadius.circular(2)),
                        ),
                      if (appId != null)
                        AppIcon(id: appId!, icon: icon, size: 22)
                      else
                        Icon(icon, size: 18, color: on ? action : c.muted),
                      if (wide) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: wide ? shortcut : '$name  ($shortcut)', child: item);
  }
}

/// Who is signed in, at the foot of the sidebar; pressing it offers Sign out
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.name, required this.email, required this.wide});
  final Account account;
  final String name;
  final String email;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final action = actionColour(Theme.of(context).brightness);
    final avatar = CircleAvatar(
      radius: 12,
      backgroundColor: action.withValues(alpha: 0.14),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: action),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: PopupMenuButton<String>(
        key: const ValueKey('account menu'),
        tooltip: 'Account',
        position: PopupMenuPosition.over,
        offset: const Offset(0, -64),
        onSelected: (v) {
          if (v == 'out') account.signOut();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            height: 30,
            child: Text(email, style: TextStyle(fontSize: 12, color: c.muted)),
          ),
          const PopupMenuItem(
            value: 'out',
            height: 32,
            child: Row(children: [Icon(Icons.logout_rounded, size: 16), SizedBox(width: 10), Text('Sign out')]),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (wide) const SizedBox(width: 10),
              avatar,
              if (wide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink),
                      ),
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded, size: 16, color: c.muted),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A program that is part of the Toolkit (Project Folder Manager): a slim header like the web apps,
/// then the program itself, with its own top bar, keys and settings (the same as the separate
/// program's, so both show the same project folders).
class _NativePanel extends StatelessWidget {
  const _NativePanel({required this.app, required this.view});
  final WorkspaceApp app;
  final Widget view;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PageHeader(title: app.name, icon: app.icon),
    body: view,
  );
}

/// One app inside the window: its toolbar and its page
class _AppPanel extends StatelessWidget {
  const _AppPanel({required this.app, required this.view, required this.model});
  final WorkspaceApp app;
  final AppViewHandle view;
  final ToolkitModel? model;

  @override
  Widget build(BuildContext context) {
    final model = this.model;
    final tool = model?.tools.where((t) => t.id == app.toolId).firstOrNull;
    final installed = tool == null ? null : model!.installedOf(tool.id);
    return Scaffold(
      appBar: PageHeader(
        title: app.name,
        icon: app.icon,
        actions: [
          ValueListenableBuilder(
            valueListenable: view.state,
            builder: (context, s, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.loading && s.problem == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8)),
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
          if (tool != null && installed?.program != null) ...[
            const SizedBox(width: 6),
            _WindowsAppButton(
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
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: view.build(context),
    );
  }
}

/// "Windows app" in an app's bar: the words when there is room, the icon alone when narrow
class _WindowsAppButton extends StatelessWidget {
  const _WindowsAppButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width < 760
      ? IconButton(tooltip: 'Windows app', onPressed: onPressed, icon: const Icon(Icons.desktop_windows_outlined))
      : OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.desktop_windows_outlined),
          label: const Text('Windows app'),
        );
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
          _Sidebar(
            page: workspaceApps.indexOf(_app) + 1,
            wide: true,
            onPick: (_) {},
            settingsPage: workspaceApps.length + 1,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _app.native
                ? _NativePanel(app: _app, view: folderManagerView(_app))
                : _AppPanel(app: _app, view: _view!, model: null),
          ),
        ],
      ),
    ),
  );
}
