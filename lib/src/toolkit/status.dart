// What a tool's card says: from the latest version in the feed and what is on this PC.
import 'detect.dart';
import 'feed.dart';
import 'version.dart';

enum ToolState {
  /// Still looking on this PC
  checking,

  /// Installed, but the latest version can't be read just now
  unknown,
  notInstalled,
  upToDate,
  updateAvailable,

  /// RoadPro on a PC without AutoCAD
  needsAutocad,
}

ToolState stateOf(FeedTool tool, Installed? installed, {bool autocad = true}) {
  if (installed == null) return ToolState.checking;
  if (!installed.found) {
    if (tool.install.kind == 'autocad-bundle' && !autocad) return ToolState.needsAutocad;
    return ToolState.notInstalled;
  }
  final latest = tool.version;
  if (latest == null) return ToolState.unknown;
  return isNewer(latest, installed.version!) ? ToolState.updateAvailable : ToolState.upToDate;
}

extension ToolStateText on ToolState {
  String get label => switch (this) {
    ToolState.checking => 'Checking',
    ToolState.unknown => 'Installed',
    ToolState.notInstalled => 'Not installed',
    ToolState.upToDate => 'Up to date',
    ToolState.updateAvailable => 'Update available',
    ToolState.needsAutocad => 'Needs AutoCAD',
  };
}
