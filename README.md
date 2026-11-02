# Survey Toolkit (beta test)

One Windows program that installs and keeps up to date every survey program from
[exceltokml.com](https://www.exceltokml.com):

| Tool | Platform |
| --- | --- |
| Excel to KML | Windows |
| RoadPro | AutoCAD plugin |
| Traverse & Level | Web app and Windows |
| Project Folder Manager | Windows |
| Slope Calculator | Web app and Windows |

**This is a test, kept apart from everything else.** The Toolkit uses each program's own
official download and installer. It changes nothing in those programs or on the website's
existing pages. See [docs/PLAN.md](docs/PLAN.md) for the phases and the separation rules, and
[docs/TOOLS.md](docs/TOOLS.md) for how each program is found, installed, updated and removed.

Status: **T3, install and update on a click (v0.2).** The Toolkit signs in, shows each tool's
installed and latest version, and installs, updates and removes them with their official
installers, checked by SHA-256. Not released yet: releases are made only when the owner says so,
as GitHub pre-releases.

## Building

Flutter 3.47.7. `flutter test` runs the tests anywhere; `flutter build windows` builds the program
on Windows, and `installer/installer.nsi` (NSIS) makes `SurveyToolkit-Setup.exe`. The **Check**
workflow does both on every change and then runs `tool/windows_check.ps1`: install the Toolkit,
have the Toolkit install, update and remove the real tools from their official downloads, and
check every step.
