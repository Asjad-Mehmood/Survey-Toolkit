// The web: no log file (the browser's console has the error); the notice still shows.
String? defaultLogPath(String appName) => null;

void append(String path, String text) {}

Future<void> openFolderOf(String path) async {}

String platformLabel() => 'Web';
