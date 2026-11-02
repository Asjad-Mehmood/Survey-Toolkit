// The apps the workspace shows inside the Toolkit's window: the three tools that are web apps.
// RoadPro (it runs inside AutoCAD) and Project Folder Manager (a Windows HTML application) are
// not part of the workspace; they stay on Home with the other tools.
import 'package:flutter/material.dart';

class WorkspaceApp {
  const WorkspaceApp({
    required this.id,
    required this.name,
    required this.short,
    required this.path,
    required this.icon,
    required this.toolId,
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
}

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
];

/// Pages the workspace keeps inside the window: the website itself. Anything else opens in the browser.
bool staysInside(Uri u) => u.scheme == 'https' && (u.host == 'www.exceltokml.com' || u.host == 'exceltokml.com');
