# Survey Toolkit

One Windows program that installs and keeps up to date every survey program from
[exceltokml.com](https://www.exceltokml.com):

| Tool | Platform |
| --- | --- |
| Excel to KML | Windows |
| RoadPro | AutoCAD plugin |
| Traverse & Level | Web app and Windows |
| Project Folder Manager | Windows |
| Slope Calculator | Web app and Windows |

**Public from v1.1.0**, for everyone with a free exceltokml.com account: download it from
[exceltokml.com/toolkit](https://www.exceltokml.com/toolkit). The Toolkit uses each program's own
official download and installer, checked by SHA-256. See [docs/PLAN.md](docs/PLAN.md) for the phases and the separation rules, and
[docs/TOOLS.md](docs/TOOLS.md) for how each program is found, installed, updated and removed.

Status: **T5, automatic updates (v0.4).** One window like the Microsoft 365 app: Home with every
tool (install, update, remove, checked by SHA-256), and Excel to KML, Traverse & Level and Slope
Calculator running inside the Toolkit, signed in already. The tools set to Automatic update by
themselves, with a Windows notification, and the Toolkit can start with Windows in the tray.
Tested end to end on a clean Windows PC (T7). The beta ran as v0.x GitHub pre-releases
([docs/BETA.md](docs/BETA.md)); v1.1.0 and later are ordinary releases, made only when the owner
says so. The website can close it to the public again: Admin → Settings → Survey Toolkit.

## Building

Flutter 3.47.7. `flutter test` runs the tests anywhere; `flutter build windows` builds the program
on Windows, and `installer/installer.nsi` (NSIS) makes `SurveyToolkit-Setup.exe`. The **Check**
workflow does both on every change and then runs `tool/windows_check.ps1`: install the Toolkit,
have the Toolkit install, update and remove the real tools from their official downloads, and
check every step.
