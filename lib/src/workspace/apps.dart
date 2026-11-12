// The apps the workspace shows inside the Toolkit's window: the three tools that are web apps, and
// Project Folder Manager, whose program is part of the Toolkit (FolderManagerView, from its own
// repository), and RoadPro's page (RoadProPanel: RoadPro itself runs inside AutoCAD).
import 'package:flutter/material.dart';

class WorkspaceApp {
  const WorkspaceApp({
    required this.id,
    required this.name,
    required this.short,
    required this.path,
    required this.icon,
    required this.toolId,
    this.native = false,
  });

  final String id;
  final String name;

  /// The sidebar's label
  final String short;

  /// The web app on exceltokml.com (also the pages /api/toolkit/handoff may go on to)
  final String path;
  final IconData icon;

  /// The same tool as a Windows program, on Home
  final String toolId;

  /// Part of the Toolkit itself (Project Folder Manager, RoadPro's page), not a web app: [path] is unused
  final bool native;
}

/// How the workspace shows an app that is part of the Toolkit (the program itself; a stand-in in tests)
typedef NativeViewFactory = Widget Function(WorkspaceApp app);

const workspaceApps = [
  WorkspaceApp(
    id: 'excel-to-kml',
    name: 'Excel to KML',
    short: 'Excel to KML',
    path: '/app',
    icon: Icons.public_rounded,
    toolId: 'excel-to-kml',
  ),
  WorkspaceApp(
    id: 'traverse',
    name: 'Traverse & Level',
    short: 'Traverse',
    path: '/traverse/app',
    icon: Icons.explore_outlined,
    toolId: 'traverse',
  ),
  WorkspaceApp(
    id: 'slope',
    name: 'Slope Calculator',
    short: 'Slope',
    path: '/slope-calculation/app',
    icon: Icons.trending_up_rounded,
    toolId: 'slope',
  ),
  WorkspaceApp(
    id: 'folder-manager',
    name: 'Project Folder Manager',
    short: 'Folders',
    path: '',
    icon: Icons.folder_copy_outlined,
    toolId: 'folder-manager',
    native: true,
  ),
  WorkspaceApp(
    id: 'roadpro',
    name: 'RoadPro',
    short: 'RoadPro',
    path: '',
    icon: Icons.alt_route_rounded,
    toolId: 'roadpro',
    native: true,
  ),
];

/// Pages the workspace keeps inside the window: the website itself. Anything else opens in the browser.
bool staysInside(Uri u) => u.scheme == 'https' && (u.host == 'www.exceltokml.com' || u.host == 'exceltokml.com');
