// Automatic updates (T5): which tools update by themselves, and which of them can be updated now.
// Kept apart from Windows and the timer so the rules can be tested.
//
//   Automatic (the default)  the Toolkit installs a new version as soon as it sees one, when the
//                            tool is closed; afterwards a Windows notification says so.
//   Ask me                   the card shows Update and nothing happens until it is pressed.
//
// Excel to KML and Traverse & Level open themselves after a silent install (docs/TOOLS.md), which
// would surprise someone in the middle of other work. So their automatic update happens when they
// are opened from the Toolkit, which opens them anyway, until their installers get /NOLAUNCH
// (docs/PLAN.md, product change 1).
import 'package:flutter/foundation.dart';

import '../state/store.dart';
import '../toolkit/detect.dart';
import '../toolkit/feed.dart';
import '../toolkit/status.dart';

enum UpdateMode { automatic, ask }

extension UpdateModeText on UpdateMode {
  String get label => switch (this) {
    UpdateMode.automatic => 'Automatic',
    UpdateMode.ask => 'Ask me',
  };
}

/// Each tool's choice, remembered on this PC
class UpdatePrefs extends ChangeNotifier {
  UpdatePrefs(this._store) {
    final modes = _store.readJson(_key)?['modes'];
    if (modes is Map) {
      for (final e in modes.entries) {
        final m = UpdateMode.values.asNameMap()[e.value];
        if (e.key is String && m != null) _modes[e.key as String] = m;
      }
    }
  }

  final Store _store;
  static const _key = 'updates';
  final Map<String, UpdateMode> _modes = {};

  UpdateMode modeOf(String toolId) => _modes[toolId] ?? UpdateMode.automatic;

  void setMode(String toolId, UpdateMode mode) {
    if (modeOf(toolId) == mode) return;
    _modes[toolId] = mode;
    _store.writeJson(_key, {
      'modes': {for (final e in _modes.entries) e.key: e.value.name},
    });
    notifyListeners();
  }
}

/// Why a tool with a new version isn't updated by itself now
enum Waits {
  /// set to Ask me
  askMe,

  /// opens itself after a silent install: updated when opened from the Toolkit
  untilOpened,

  /// the website couldn't check the download just now
  noDownload,

  /// failed too often at this version: the user is told and presses Update
  gaveUp,
}

class UpdatePlan {
  const UpdatePlan(this.now, this.waiting);

  /// To update now, in this order
  final List<FeedTool> now;
  final Map<String, Waits> waiting;
}

/// Which installed tools with a new version to update now. Only updates: a tool that isn't on
/// this PC is never installed by itself.
UpdatePlan planUpdates({
  required List<FeedTool> tools,
  required Installed? Function(String id) installed,
  required UpdateMode Function(String id) modeOf,
  bool autocad = true,
  Map<String, String> gaveUp = const {},
}) {
  final now = <FeedTool>[];
  final waiting = <String, Waits>{};
  for (final t in tools) {
    if (stateOf(t, installed(t.id), autocad: autocad) != ToolState.updateAvailable) continue;
    if (modeOf(t.id) == UpdateMode.ask) {
      waiting[t.id] = Waits.askMe;
    } else if (t.download == null) {
      waiting[t.id] = Waits.noDownload;
    } else if (gaveUp[t.id] == t.version) {
      waiting[t.id] = Waits.gaveUp;
    } else if (t.install.opensAfterSilentInstall) {
      waiting[t.id] = Waits.untilOpened;
    } else {
      now.add(t);
    }
  }
  return UpdatePlan(now, waiting);
}

/// A tool to update on the way to opening it (Automatic, and it opens itself after its installer)
bool updatesWhenOpened(FeedTool t, ToolState state, UpdateMode mode) =>
    state == ToolState.updateAvailable &&
    mode == UpdateMode.automatic &&
    t.install.opensAfterSilentInstall &&
    t.download != null;

/// The notification after automatic updates: "Slope Calculator updated to 1.0.3"
String? updatedText(List<(String name, String version)> done) {
  if (done.isEmpty) return null;
  if (done.length == 1) return '${done.first.$1} updated to ${done.first.$2}';
  return 'Updated: ${done.map((d) => '${d.$1} ${d.$2}').join(', ')}';
}
