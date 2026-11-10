# webview_windows 0.4.0, with two changes for the Survey Toolkit

A copy of [webview_windows](https://github.com/jnschulze/flutter-webview-windows) 0.4.0 from
pub.dev (BSD 3-Clause, see LICENSE), used through the path dependency in the Toolkit's
`pubspec.yaml`. Only `lib/`, `windows/`, the licence, the change log and `pubspec.yaml` are kept.

## 1. A press lands where the pointer is

`lib/src/webview.dart`, in the `Listener` of the `Webview` widget: before a mouse or pen press
and release is handed to WebView2, the pointer is first moved to where the press is
(`_setCursorPos(ev.localPosition)`).

The package sends a press to WebView2 at the last position it was given, which for a mouse is
where it hovers. A pen sends no hover events here, so its press went to the page where the pen
had last lifted, and only its release went to the right place: a tap on a button or a drop-down
did nothing, or something else entirely (found with injected pen input on a Windows runner).
Touch has its own path (`SendPointerInput`) and is unchanged.

## 2. The wheel turns where the pointer is

`windows/webview.cc`, `Webview::SendScroll`: the mouse wheel (and a touch pad's two-finger scroll)
goes to the page through the DevTools protocol, `Input.dispatchMouseEvent` with `mouseWheel` at
the pointer's position in the page, a real wheel event there. `lib/src/webview.dart` moves the
pointer to the wheel's position first (`_setCursorPos(signal.localPosition)`), as for a press.

The package sent the wheel with `SendMouseInput` at the page's top-left corner, (0, 0). A page
that scrolls as a whole still moved; in a page whose scrolling part is lower down, as in the
Flutter web apps (Slope Calculator), it reached the header at the top and nothing scrolled. Sent
with `SendMouseInput` at the pointer's position instead, WebView2 dropped it altogether (this
WebView is drawn off-screen for a message-only window). Both were seen with the real mouse wheel
in the Toolkit's window on a Windows runner (`tool/scroll_check.ps1`). If the DevTools protocol
call fails, the package's own way is used.
