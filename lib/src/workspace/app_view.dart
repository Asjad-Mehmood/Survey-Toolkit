// One web app inside the Toolkit's window. The real one is Microsoft Edge WebView2 (the browser
// built into Windows 10 and 11); the tests use a stand-in.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'apps.dart';

@immutable
class AppViewState {
  const AppViewState({this.loading = true, this.url, this.canGoBack = false, this.problem});
  final bool loading;
  final String? url;
  final bool canGoBack;

  /// Shown instead of the page (no WebView2 on this PC)
  final String? problem;

  AppViewState copyWith({bool? loading, String? url, bool? canGoBack, String? problem}) => AppViewState(
    loading: loading ?? this.loading,
    url: url ?? this.url,
    canGoBack: canGoBack ?? this.canGoBack,
    problem: problem ?? this.problem,
  );
}

/// A running web app: its page, and the toolbar's controls
abstract class AppViewHandle {
  Widget build(BuildContext context);
  ValueListenable<AppViewState> get state;
  Future<void> back();
  Future<void> reload();

  /// Signed out: forget this window's sign-in (its cookies)
  Future<void> forget();
  void dispose();
}

/// Makes the view for [app]; [start] gives the first address (the sign-in handover, or the app)
typedef AppViewFactory = AppViewHandle Function(WorkspaceApp app, Future<String> Function() start);

AppViewHandle webView2Factory(WorkspaceApp app, Future<String> Function() start) => WebView2Handle(app, start);

/// The address WebView2 is pointed at when it isn't on this PC
const webView2Download = 'https://developer.microsoft.com/microsoft-edge/webview2/';

class WebView2Handle implements AppViewHandle {
  WebView2Handle(this.app, this._start) {
    unawaited(_open());
  }

  final WorkspaceApp app;
  final Future<String> Function() _start;
  final _controller = WebviewController();
  final _state = ValueNotifier(const AppViewState());
  final _subs = <StreamSubscription<Object?>>[];
  bool _ready = false;
  bool _disposed = false;

  @override
  ValueListenable<AppViewState> get state => _state;

  Future<void> _open() async {
    try {
      if (await WebviewController.getWebViewVersion() == null) {
        _state.value = const AppViewState(
          loading: false,
          problem: 'This PC doesn\'t have Microsoft Edge WebView2, which shows the web apps inside the Toolkit.',
        );
        return;
      }
      await _controller.initialize();
      if (_disposed) return;
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      _subs
        ..add(_controller.url.listen(_onUrl))
        ..add(
          _controller.loadingState.listen(
            (s) => _state.value = _state.value.copyWith(loading: s == LoadingState.loading),
          ),
        )
        ..add(_controller.historyChanged.listen((h) => _state.value = _state.value.copyWith(canGoBack: h.canGoBack)));
      _ready = true;
      _state.value = _state.value.copyWith();
      await _controller.loadUrl(await _start());
    } catch (e) {
      if (!_disposed) _state.value = AppViewState(loading: false, problem: '${app.name} could not be shown here: $e');
    }
  }

  /// A link off the website opens in the browser; the window stays where it was
  void _onUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || url == 'about:blank' || staysInside(u) || u.host == 'localhost') {
      _state.value = _state.value.copyWith(url: url);
      return;
    }
    unawaited(launchUrl(u, mode: LaunchMode.externalApplication));
    unawaited(_controller.goBack());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _state,
    builder: (context, s, _) {
      if (s.problem != null) return _Problem(text: s.problem!);
      if (!_ready) return const Center(child: CircularProgressIndicator());
      return Webview(_controller);
    },
  );

  @override
  Future<void> back() async => _ready ? _controller.goBack() : null;

  @override
  Future<void> reload() async => _ready ? _controller.reload() : null;

  @override
  Future<void> forget() async {
    if (_ready) await _controller.clearCookies();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _controller.dispose();
    _state.dispose();
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Notice(text, kind: NoticeKind.warning),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => launchUrl(Uri.parse(webView2Download), mode: LaunchMode.externalApplication),
              child: const Text('Get WebView2 from Microsoft'),
            ),
            const SizedBox(height: 8),
            Text(
              'Or use the app in your browser, or as a Windows program from Home.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
