// The error log on a computer: logs\errors.log next to the program, 1 MB at most (the older half
// is kept as errors.log.1). A log that can't be written never stops the program.
import 'dart:io';

String? defaultLogPath(String appName) {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    return home == null ? null : '$home/Library/Logs/$appName/errors.log';
  }
  final dir = File(Platform.resolvedExecutable).parent.path;
  final sep = Platform.pathSeparator;
  return '$dir${sep}logs${sep}errors.log';
}

void append(String path, String text) {
  try {
    final f = File(path);
    f.parent.createSync(recursive: true);
    if (f.existsSync() && f.lengthSync() > 1024 * 1024) {
      final old = File('$path.1');
      if (old.existsSync()) old.deleteSync();
      f.renameSync(old.path);
    }
    File(path).writeAsStringSync(text, mode: FileMode.append, flush: true);
  } catch (_) {
    // nothing to do: the notice still shows
  }
}

Future<void> openFolderOf(String path) async {
  try {
    final dir = File(path).parent..createSync(recursive: true);
    final opener = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.start(opener, [dir.path]);
  } catch (_) {
    // no file manager: nothing to open
  }
}

String platformLabel() {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return Platform.operatingSystem;
}
