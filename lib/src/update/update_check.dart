// The Toolkit's self-update rules, kept apart from Windows so they can be tested. The beta's
// releases (v0.x) were GitHub pre-releases, which GitHub's "latest" link skips, and the
// repository has empty releases too, so it reads the list of releases and takes the newest one
// with both files: v1.1.0 and later, ordinary releases, the same way.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../toolkit/version.dart';

const manifestName = 'latest.json';
const installerName = 'SurveyToolkit-Setup.exe';

class UpdateInfo {
  const UpdateInfo(this.version, this.sha256);
  final String version;
  final String sha256;

  /// latest.json: {"version":"0.1.0","sha256":"…64 hex…"}; null when it isn't one
  static UpdateInfo? parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final v = j['version'], h = j['sha256'];
      if (v is! String || h is! String) return null;
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v) || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(h)) return null;
      return UpdateInfo(v, h.toLowerCase());
    } on FormatException {
      return null;
    }
  }
}

/// The files of one release
class ReleaseFiles {
  const ReleaseFiles({required this.tag, required this.manifestUrl, required this.installerUrl});
  final String tag;
  final String manifestUrl;
  final String installerUrl;
}

/// From GitHub's list of releases (newest first): the newest that isn't a draft and has both
/// latest.json and the installer, on github.com
ReleaseFiles? newestRelease(Object? releases) {
  if (releases is! List) return null;
  for (final r in releases) {
    if (r is! Map || r['draft'] == true) continue;
    String? url(String name) {
      for (final a in (r['assets'] as List?) ?? const []) {
        if (a is Map && a['name'] == name && a['browser_download_url'] is String) {
          final u = Uri.tryParse(a['browser_download_url'] as String);
          if (u != null && u.scheme == 'https' && u.host == 'github.com') return u.toString();
        }
      }
      return null;
    }

    final m = url(manifestName), i = url(installerName);
    if (m != null && i != null) return ReleaseFiles(tag: '${r['tag_name'] ?? ''}', manifestUrl: m, installerUrl: i);
  }
  return null;
}

/// Is [info] an update for [current]?
bool offersUpdate(UpdateInfo? info, String current) => info != null && isNewer(info.version, current);

bool sha256Matches(List<int> bytes, String expected) => sha256.convert(bytes).toString() == expected.toLowerCase();
