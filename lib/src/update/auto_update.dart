// Automatic updates (T5): when the Toolkit starts, every 4 hours while it runs (in the tray too),
// and from the tray's "Check for updates now", it reads the feed again, looks on this PC, and
// updates each tool set to Automatic (lib/src/update/update_prefs.dart), one at a time, exactly as
// the Update button does: the same download, SHA-256 check and installer (lib/src/toolkit/
// installer.dart). A notification says what was updated.
//
//   - A tool that is open is never updated: it is tried again after 30 minutes.
//   - A failed update is tried again at the next check; after 3 failures at the same version the
//     Toolkit stops trying, says so once, and leaves it to the Update button.
//   - When the user is installing something themselves, the automatic updates wait for the next
//     check.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../brand.dart';
import '../toolkit/feed.dart';
import '../toolkit/installer.dart';
import '../toolkit/toolkit_model.dart';
import 'background.dart';
import 'update_prefs.dart';

class AutoUpdater extends ChangeNotifier {
  AutoUpdater({
    required this.model,
    required this.background,
    this.alsoCheck,
    this.every = const Duration(hours: 4),
    this.retryOpen = const Duration(minutes: 30),
    this.maxTries = 3,
  });

  final ToolkitModel model;
  final Background background;

  /// Run with each check as well (the Toolkit's own update)
  final Future<void> Function()? alsoCheck;
  final Duration every;
  final Duration retryOpen;
  final int maxTries;

  Tray get tray => background.tray;

  Timer? _timer;
  Timer? _retry;
  bool _updating = false;
  bool get updating => _updating;

  DateTime? nextCheck;

  /// tool id → the version it stopped trying
  final Map<String, String> gaveUp = {};
  final Map<String, int> _failures = {};

  /// Checks now and then every [every]
  void start() {
    stop();
    _timer = Timer.periodic(every, (_) => unawaited(check()));
    nextCheck = DateTime.now().add(every);
    tray.onCheckNow = () => unawaited(check());
    // the Toolkit's own update was looked for as it opened
    unawaited(check(self: false));
  }

  void stop() {
    _timer?.cancel();
    _retry?.cancel();
    _timer = null;
    _retry = null;
    nextCheck = null;
    tray.onCheckNow = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Reads the feed, looks on this PC, then updates what is due; [self]: the Toolkit's own update too
  Future<void> check({bool self = true}) async {
    if (_timer != null) nextCheck = DateTime.now().add(every);
    await model.refresh();
    await updateDue();
    final also = alsoCheck;
    if (self && also != null) await also();
  }

  /// Updates each tool that is due, one at a time; what was updated
  Future<List<(FeedTool, JobResult)>> updateDue() async {
    if (_updating || model.installer == null) return const [];
    _updating = true;
    notifyListeners();
    final results = <(FeedTool, JobResult)>[];
    var open = false;
    try {
      final plan = planUpdates(
        tools: model.tools,
        installed: model.installedOf,
        modeOf: model.updates.modeOf,
        autocad: model.hasAutocad,
        gaveUp: gaveUp,
      );
      for (final t in plan.now) {
        // the user started something: the rest waits for the next check
        if (model.jobRunning) break;
        final r = await model.install(t, automatic: true);
        results.add((t, r));
        if (r.blocked) {
          open = true;
        } else if (r.ok) {
          _failures.remove('${t.id}@${t.version}');
        } else {
          final key = '${t.id}@${t.version}';
          final n = (_failures[key] ?? 0) + 1;
          _failures[key] = n;
          if (n >= maxTries && t.version != null) {
            gaveUp[t.id] = t.version!;
            await tray.notify(
              '${t.name} wasn\'t updated',
              'The Toolkit tried $n times. Open the Survey Toolkit to see why and update it there.',
            );
          }
        }
      }
    } finally {
      _updating = false;
      notifyListeners();
    }
    final text = updatedText([
      for (final (t, r) in results)
        if (r.ok) (t.name, r.version ?? t.version ?? ''),
    ]);
    if (text != null) await tray.notify(appName, text);
    if (open) {
      _retry?.cancel();
      _retry = Timer(retryOpen, () async {
        await model.detect();
        await updateDue();
      });
    }
    return results;
  }
}
