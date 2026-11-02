// The tool list from exceltokml.com/api/toolkit/feed (the website's lib/toolkit/feed.ts): for each
// tool its latest version, the download with its SHA-256, and how it is found on a PC.
//
// The five tools are also built in ([builtInTools]), with how to find each one but no version, so
// the Toolkit can show what is installed before it has ever reached the website, and so the
// Windows test can check finding them without the website.
import 'version.dart';

/// Downloads come only from these, over HTTPS
const allowedDownloadHosts = {'www.exceltokml.com', 'exceltokml.com', 'github.com'};

bool isAllowedUrl(String url) {
  final u = Uri.tryParse(url);
  return u != null && u.scheme == 'https' && allowedDownloadHosts.contains(u.host);
}

class FeedDownload {
  const FeedDownload({required this.url, required this.file, required this.size, required this.sha256});
  final String url;
  final String file;
  final int? size;
  final String sha256;

  static FeedDownload? from(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final url = j['url'], file = j['file'], sha = j['sha256'], size = j['size'];
    if (url is! String || file is! String || sha is! String) return null;
    if (!isAllowedUrl(url) || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
    return FeedDownload(url: url, file: file, size: size is int ? size : null, sha256: sha);
  }
}

/// How a tool is found (and later installed) on a PC
class InstallInfo {
  const InstallInfo({
    required this.kind,
    this.registryKey,
    this.exe = const [],
    this.opensAfterSilentInstall = false,
    this.files = const [],
    this.keep = const [],
    this.main,
    this.needs,
  });

  /// installer (NSIS, in the registry), autocad-bundle (RoadPro) or zip (Project Folder Manager)
  final String kind;
  final String? registryKey;
  final List<String> exe;
  final bool opensAfterSilentInstall;
  final List<String> files;
  final List<String> keep;
  final String? main;
  final String? needs;

  static List<String> _strings(Object? v) => [if (v is List) ...v.whereType<String>()];

  static InstallInfo? from(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final kind = j['kind'];
    if (kind is! String || !const {'installer', 'autocad-bundle', 'zip'}.contains(kind)) return null;
    final key = j['registryKey'];
    if (kind == 'installer' && (key is! String || !RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(key))) return null;
    bool plainName(String s) => RegExp(r'^[A-Za-z0-9 _.&()-]{1,80}$').hasMatch(s) && !s.contains('..');
    return InstallInfo(
      kind: kind,
      registryKey: key is String ? key : null,
      exe: _strings(j['exe']).where(plainName).toList(),
      opensAfterSilentInstall: j['opensAfterSilentInstall'] == true,
      files: _strings(j['files']).where(plainName).toList(),
      keep: _strings(j['keep']).where(plainName).toList(),
      main: j['main'] is String && plainName(j['main']! as String) ? j['main']! as String : null,
      needs: j['needs'] is String ? j['needs']! as String : null,
    );
  }
}

class FeedTool {
  const FeedTool({
    required this.id,
    required this.name,
    required this.platform,
    required this.page,
    required this.install,
    this.webApp,
    this.version,
    this.released,
    this.notes,
    this.download,
    this.problems = const [],
  });

  final String id;
  final String name;
  final String platform;
  final String page;
  final String? webApp;

  /// null when the website couldn't read it just now
  final String? version;
  final String? released;
  final String? notes;
  final FeedDownload? download;
  final InstallInfo install;
  final List<String> problems;

  static FeedTool? from(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final id = j['id'], name = j['name'], platform = j['platform'], page = j['page'];
    final install = InstallInfo.from(j['install']);
    if (id is! String || name is! String || platform is! String || page is! String || install == null) return null;
    if (!isAllowedUrl(page)) return null;
    final version = j['version'];
    final webApp = j['webApp'], notes = j['notes'];
    return FeedTool(
      id: id,
      name: name,
      platform: platform,
      page: page,
      webApp: webApp is String && isAllowedUrl(webApp) ? webApp : null,
      version: version is String && looksLikeVersion(version) ? version : null,
      released: j['released'] is String ? j['released']! as String : null,
      notes: notes is String && isAllowedUrl(notes) ? notes : null,
      download: FeedDownload.from(j['download']),
      install: install,
      problems: [if (j['problems'] is List) ...(j['problems']! as List).whereType<String>()],
    );
  }
}

class Feed {
  const Feed({required this.tools, this.generated});
  final List<FeedTool> tools;
  final DateTime? generated;

  /// Feed format this Toolkit reads
  static const schema = 1;

  /// null when it isn't a feed this Toolkit can read
  static Feed? from(Object? j) {
    if (j is! Map<String, Object?> || j['schema'] != schema) return null;
    final list = j['tools'];
    if (list is! List) return null;
    final tools = list.map(FeedTool.from).whereType<FeedTool>().toList();
    if (tools.isEmpty) return null;
    return Feed(tools: tools, generated: DateTime.tryParse((j['generated'] as String?) ?? ''));
  }
}

/// The five tools as T0 found them (the Toolkit's docs/TOOLS.md): how to find each one, no versions
const builtInTools = [
  FeedTool(
    id: 'excel-to-kml',
    name: 'Excel to KML',
    platform: 'Windows',
    page: 'https://www.exceltokml.com/download',
    install: InstallInfo(
      kind: 'installer',
      registryKey: 'ExcelToKMLPro',
      exe: ['ExcelToKML.exe', 'ExcelToKMLPro.exe'],
      opensAfterSilentInstall: true,
    ),
  ),
  FeedTool(
    id: 'roadpro',
    name: 'RoadPro',
    platform: 'AutoCAD plugin',
    page: 'https://www.exceltokml.com/roadpro',
    install: InstallInfo(
      kind: 'autocad-bundle',
      files: ['RoadPro.lsp', 'RP_PAVER.pat', 'README.txt'],
      main: 'RoadPro.lsp',
      needs: 'Full AutoCAD, Civil 3D or Map 3D 2014 or newer (not AutoCAD LT)',
    ),
  ),
  FeedTool(
    id: 'traverse',
    name: 'Traverse & Level',
    platform: 'Web app and Windows',
    page: 'https://www.exceltokml.com/traverse',
    webApp: 'https://www.exceltokml.com/traverse/app',
    install: InstallInfo(
      kind: 'installer',
      registryKey: 'TraversePro',
      exe: ['TraverseLevel.exe', 'TraversePro.exe'],
      opensAfterSilentInstall: true,
    ),
  ),
  FeedTool(
    id: 'folder-manager',
    name: 'Project Folder Manager',
    platform: 'Windows',
    page: 'https://www.exceltokml.com/project-folder-manager',
    install: InstallInfo(
      kind: 'zip',
      files: ['Project_Folder_Manager.exe', 'Project_Folder_Manager.hta', 'READ_ME.txt', 'dashboard_icon.ico'],
      keep: ['Project_Folder_Manager_config.txt'],
      main: 'Project_Folder_Manager.exe',
    ),
  ),
  FeedTool(
    id: 'slope',
    name: 'Slope Calculator',
    platform: 'Web app and Windows',
    page: 'https://www.exceltokml.com/slope-calculation',
    webApp: 'https://www.exceltokml.com/slope-calculation/app',
    install: InstallInfo(kind: 'installer', registryKey: 'SlopeCalculator', exe: ['SlopeCalculator.exe']),
  ),
];
