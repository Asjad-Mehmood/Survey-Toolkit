# webview_windows 0.4.0, with one change for the Survey Toolkit

A copy of [webview_windows](https://github.com/jnschulze/flutter-webview-windows) 0.4.0 from
pub.dev (BSD 3-Clause, see LICENSE), used through the path dependency in the Toolkit's
`pubspec.yaml`. Only `lib/`, `windows/`, the licence, the change log and `pubspec.yaml` are kept.

## The change

`lib/src/webview.dart`, in the `Listener` of the `Webview` widget: before a mouse or pen press
and release is handed to WebView2, the pointer is first moved to where the press is
(`_setCursorPos(ev.localPosition)`).

The package sends a press to WebView2 at the last position it was given, which for a mouse is
where it hovers. A pen sends no hover events here, so its press went to the page where the pen
had last lifted, and only its release went to the right place: a tap on a button or a drop-down
did nothing, or something else entirely (found with injected pen input on a Windows runner).
Touch has its own path (`SendPointerInput`) and is unchanged.
