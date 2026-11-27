// Errors the program did not expect. They are written to a log file (errors.log in the logs
// folder next to the program), shown as a short notice instead of a grey screen, and the person
// can send them on with Report a problem. Started once, in main(); tests never start it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'log_file_stub.dart' if (dart.library.io) 'log_file_io.dart' as file;

/// The last error, for the notice
class CrashNote {
  const CrashNote(this.message, this.when);
  final String message;
  final DateTime when;
}

abstract final class CrashLog {
  static String? _path;
  static String _who = '';

  /// The error log's file, or null when there is none (the web, or not started)
  static String? get path => _path;

  /// The last error since the program opened; the notice shows it until it is closed
  static final ValueNotifier<CrashNote?> last = ValueNotifier(null);

  /// Catches every error from here on. [logPath] null: logs\errors.log next to the program
  /// (on a Mac ~/Library/Logs/`app`).
  static void start({required String appName, required String version, String? logPath}) {
    _path = logPath ?? file.defaultLogPath(appName);
    _who = '$appName $version (${file.platformLabel()})';
    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      record(details.exception, details.stack, where: details.context?.toDescription());
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return true;
    };
    // in a release a part that fails to draw says so, instead of a grey box
    if (!kDebugMode) ErrorWidget.builder = (_) => const BrokenPart();
  }

  /// Writes the error to the log and shows the notice
  static void record(Object error, StackTrace? stack, {String? where}) {
    final now = DateTime.now();
    final p = _path;
    if (p != null) {
      file.append(p, '[${now.toIso8601String()}] $_who${where == null ? '' : ', $where'}\n$error\n${stack ?? ''}\n');
    }
    final message = error.toString().split('\n').first;
    // after the frame: an error while drawing must not redraw in the middle of drawing
    Timer.run(() => last.value = CrashNote(message.length > 160 ? '${message.substring(0, 160)}…' : message, now));
  }

  /// Opens the folder with the error log (File Explorer on Windows)
  static Future<void> openFolder() async {
    final p = _path;
    if (p != null) await file.openFolderOf(p);
  }

  /// "Windows", "macOS" or "Web": sent with Report a problem
  static String get platform => file.platformLabel();
}

/// What a part of a screen shows when it could not be drawn (release builds only)
class BrokenPart extends StatelessWidget {
  const BrokenPart({super.key});

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(12),
    color: const Color(0x14FF5252),
    child: const Text(
      'This part could not be shown. The error is in the error log.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: Color(0xFFB3261E)),
      textDirection: TextDirection.ltr,
    ),
  );
}

/// The notice at the bottom of the window after an error. Put it round the app with
/// MaterialApp.builder: `builder: (context, child) => CrashNotice(onReport: …, child: child!)`.
class CrashNotice extends StatelessWidget {
  const CrashNotice({super.key, required this.child, required this.onReport});
  final Widget child;

  /// Opens Report a problem (the website's contact form, with the program and version)
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: child),
      ValueListenableBuilder<CrashNote?>(
        valueListenable: CrashLog.last,
        builder: (context, note, _) => note == null
            ? const SizedBox.shrink()
            : Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _NoticeCard(note: note, onReport: onReport),
                    ),
                  ),
                ),
              ),
      ),
    ],
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.note, required this.onReport});
  final CrashNote note;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final fg = s.onInverseSurface;
    final button = TextButton.styleFrom(foregroundColor: s.inversePrimary);
    return Material(
      key: const ValueKey('crash notice'),
      color: s.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: fg, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Something went wrong',
                        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (CrashLog.path != null)
                  TextButton(style: button, onPressed: CrashLog.openFolder, child: const Text('Error log')),
                TextButton(style: button, onPressed: onReport, child: const Text('Report a problem')),
                TextButton(style: button, onPressed: () => CrashLog.last.value = null, child: const Text('Close')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
