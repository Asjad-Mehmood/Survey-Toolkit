// The Tools page's state: the feed from the website, what is installed on this PC, each tool's
// status, and the install, update or uninstall in progress (one at a time, lib/src/toolkit/
// installer.dart).
//
// After each check the Toolkit tells the website (testers only, /api/toolkit/event) this PC's
// name, Windows version and installed versions, and after each job what it did, for
// Admin → Toolkit (beta).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../account/api.dart';
import '../brand.dart';
import '../state/store.dart';
import 'detect.dart';
import 'feed.dart';
import 'installer.dart';
import 'status.dart';

class ToolkitModel extends ChangeNotifier {
  ToolkitModel({required this.account, required this.store, required this.detector, this.installer}) {
    final kept = Feed.from(store.readJson(_feedKey));
    if (kept != null) {
      _feed = kept;
      fromKept = true;
    }
    final at = store.read(_checkedKey);
    checkedAt = at == null ? null : DateTime.tryParse(at);
  }

  final Account account;
  final Store store;
  final Detector detector;

  /// null: install and uninstall aren't offered (look only)
  final ToolInstaller? installer;

  static const _feedKey = 'feed';
  static const _checkedKey = 'checked';
  static const _deviceKey = 'device';

  /// Where the folder of a Project Folder Manager the user unzipped themselves is kept
  static const folderKey = 'folder-manager-folder';

  Api get api => account.api;

  Feed? _feed;

  /// The tools: from the website's feed, or the built-in list before it has been reached
  List<FeedTool> get tools => _feed?.tools ?? builtInTools;

  /// The feed shown was kept from an earlier check (no connection now)
  bool fromKept = false;

  /// The website hasn't been reached yet, so there are no latest versions
  bool get noFeed => _feed == null;

  DateTime? checkedAt;
  bool busy = false;
  String? problem;

  final Map<String, Installed> _installed = {};
  bool _autocad = true;

  Installed? installedOf(String id) => _installed[id];
  bool get hasAutocad => _autocad;

  ToolState stateOfTool(FeedTool t) => stateOf(t, _installed[t.id], autocad: _autocad);

  int countIn(ToolState s) => tools.where((t) => stateOfTool(t) == s).length;

  /// The folder of a Project Folder Manager the user unzipped themselves
  String? get folderManagerFolder => store.read(folderKey);

  /// This PC's id for the website: made once, kept
  String get deviceId {
    final kept = store.read(_deviceKey);
    if (kept != null && RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(kept)) return kept;
    final r = math.Random.secure();
    final id = 'pc-${List.generate(24, (_) => '0123456789abcdef'[r.nextInt(16)]).join()}';
    store.write(_deviceKey, id);
    return id;
  }

  /// Reads the feed and looks on this PC again
  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    problem = null;
    notifyListeners();
    try {
      try {
        final j = await api.call('GET', '/api/toolkit/feed');
        final feed = Feed.from(j);
        if (feed == null) {
          problem = 'The tool list from exceltokml.com could not be read. This Toolkit may need an update.';
        } else {
          _feed = feed;
          fromKept = false;
          store.writeJson(_feedKey, j);
          checkedAt = DateTime.now();
          store.write(_checkedKey, checkedAt!.toIso8601String());
        }
      } on ApiError catch (e) {
        problem = e.status == null
            ? 'No connection to exceltokml.com. Showing what was known at the last check.'
            : e.message;
        if (_feed != null) fromKept = true;
      }
      await detect();
      unawaited(report());
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Looks on this PC for each tool
  Future<void> detect() async {
    _autocad = await detector.hasAutocad();
    for (final t in tools) {
      try {
        _installed[t.id] = await detector.find(t);
      } catch (_) {
        _installed[t.id] = Installed.none;
      }
    }
    notifyListeners();
  }

  /// What this PC has, for Admin → Toolkit (beta). Problems are ignored: it is sent again next time.
  Future<void> report({List<Map<String, Object?>> events = const []}) async {
    if (account.beta != BetaAccess.tester) return;
    try {
      await api.call('POST', '/api/toolkit/event', {
        'device': {
          'id': deviceId,
          'name': _safe(() => Platform.localHostname),
          'windows': _safe(() => Platform.operatingSystemVersion),
          'toolkitVersion': appVersion,
          'tools': {for (final t in tools) t.id: _installed[t.id]?.version ?? ''},
        },
        'events': events,
      });
    } on ApiError {
      // offline or refused: the next check sends it again
    }
  }

  static String _safe(String Function() read) {
    try {
      return read();
    } catch (_) {
      return '';
    }
  }

  /// Opens an installed program
  Future<bool> open(FeedTool t) async {
    final program = _installed[t.id]?.program;
    if (program == null || !File(program).existsSync()) return false;
    try {
      await Process.start(
        program,
        const [],
        mode: ProcessStartMode.detached,
        workingDirectory: File(program).parent.path,
      );
    } catch (_) {
      return false;
    }
    unawaited(
      report(
        events: [
          {'tool': t.id, 'action': 'opened', 'to': _installed[t.id]?.version ?? ''},
        ],
      ),
    );
    return true;
  }

  /// The user points at the Project Folder Manager they unzipped themselves
  Future<void> setFolderManagerFolder(String folder) async {
    store.write(folderKey, folder);
    for (final t in tools.where((t) => t.install.kind == 'zip')) {
      _installed[t.id] = await detector.find(t);
    }
    notifyListeners();
    unawaited(report());
  }

  // ------------------------------------------------------------------ install, update, uninstall

  /// The tool with a job running, and how far it is
  String? jobTool;
  JobProgress? jobProgress;

  /// The last job's result on each tool's card, until the next one
  final Map<String, JobResult> results = {};

  bool get jobRunning => jobTool != null;

  /// Can the Toolkit install or update this tool now?
  bool canInstall(FeedTool t) => installer != null && t.download != null && t.version != null && !jobRunning;

  /// Why the Toolkit can't uninstall this tool, or null when it can
  String? cannotUninstall(FeedTool t) {
    final i = _installed[t.id];
    if (installer == null || i == null) return 'Not available';
    return installer!.cannotUninstall(t, i);
  }

  Future<JobResult> install(FeedTool t) async {
    final before = _installed[t.id];
    final from = before != null && before.found ? before.version : null;
    return _job(
      t,
      (inst) => inst.install(t, current: before != null && before.found ? before : null, onProgress: _progress),
      (r) => {
        'tool': t.id,
        'action': r.ok ? (from == null ? 'installed' : 'updated') : 'failed',
        'from': from ?? '',
        'to': r.version ?? t.version ?? '',
        if (!r.ok) 'message': r.message,
      },
    );
  }

  Future<JobResult> uninstall(FeedTool t) async {
    final before = _installed[t.id] ?? Installed.none;
    return _job(
      t,
      (inst) => inst.uninstall(t, before),
      (r) => {
        'tool': t.id,
        'action': r.ok ? 'uninstalled' : 'failed',
        'from': before.version ?? '',
        if (!r.ok) 'message': 'uninstall: ${r.message}',
      },
    );
  }

  void _progress(JobProgress p) {
    jobProgress = p;
    notifyListeners();
  }

  Future<JobResult> _job(
    FeedTool t,
    Future<JobResult> Function(ToolInstaller) work,
    Map<String, Object?> Function(JobResult) event,
  ) async {
    final inst = installer;
    if (inst == null) return const JobResult.failed('Installing isn\'t available in this Toolkit.');
    if (jobRunning) return const JobResult.blocked('Another tool is being installed. Wait for it to finish.');
    jobTool = t.id;
    jobProgress = null;
    results.remove(t.id);
    notifyListeners();
    JobResult r;
    try {
      r = await work(inst);
    } catch (e) {
      r = JobResult.failed('Something went wrong: $e');
    }
    try {
      _installed[t.id] = await detector.find(t);
    } catch (_) {
      // shown as before; the next check looks again
    }
    results[t.id] = r;
    jobTool = null;
    jobProgress = null;
    notifyListeners();
    // a tool that was open: nothing happened, nothing to report
    if (!r.blocked) unawaited(report(events: [event(r)]));
    return r;
  }
}
