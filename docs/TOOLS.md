# The five tools: how the Toolkit finds, installs, updates, opens and removes each one

T0 research, read from each product's installer script, update code and published files on
1 November 2026. `tool/probe_tools.ps1` (the **Probe** workflow) checks the Windows parts on a
clean Windows PC, on every change and every Monday.

## At a glance

| | Excel to KML | Traverse & Level | Slope Calculator | RoadPro | Project Folder Manager |
| --- | --- | --- | --- | --- | --- |
| Download | GitHub release | GitHub release | GitHub release | Website zip | Website zip |
| Latest (1 Nov 2026) | 4.4.0 | 2.1.0 | 1.0.3 | 3.4 | 6.2 |
| Machine-readable version | `latest.json` | `latest.json` | `latest.json` (**missing from v1.0.3**) | none: inside `RoadPro.lsp` | none: inside the `.hta` |
| Install | NSIS installer | NSIS installer | NSIS installer | copy files, load in AutoCAD | unzip |
| Needs administrator | **No** (per user) | **No** | **No** | No | No |
| Silent switch | `/S` | `/S` | `/S` (`/S /UPDATE` reopens) | n/a | n/a |
| Opens itself after `/S` | **Yes, always** | **Yes, always** | Only with `/UPDATE` | n/a | n/a |
| If open during `/S` | **Closed by force** | **Closed by force** | **Closed by force** | AutoCAD keeps the old one until restart | the old `.hta` stays open |
| Own update check | Yes, asks first | Yes, asks first | Yes | No | No |

**Confirmed on Windows** by the Probe run of 1 November 2026
([run 41336925385](https://github.com/Asjad-Mehmood/Survey-Toolkit/actions/runs/41336925385)):

- **Install and uninstall:** all three installers installed silently with exit code 0, put the
  latest version in the registry, and uninstalled silently and cleanly.
- **Opening after install:** Excel to KML and Traverse & Level opened themselves; Slope
  Calculator didn't.
- **An open copy:** all three closed it by force.
- **The zips:** both had the expected files and versions (RoadPro 3.4, Project Folder Manager
  6.2).
- **Slope Calculator:** `latest.json` is missing.

**No tool needs administrator rights**, so the Toolkit can be per-user too and update with no
Windows "Allow changes?" prompt and no background service. That was the biggest risk in the plan.

## Excel to KML

- **Releases:** `github.com/Asjad-Mehmood/kml-convertor` (the public releases repository; the
  code is private in `kml-convertor-src`). Every release has `ExcelToKML-Setup.exe`, the same
  file again as `ExcelToKMLPro-Lite-Setup.exe` for copies older than 4.3.1, and
  `latest.json` = `{"version":"4.4.0","sha256":"…"}`.
- **Latest:** `https://github.com/Asjad-Mehmood/kml-convertor/releases/latest/download/latest.json`
- **Installed?** `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\ExcelToKMLPro`,
  value `DisplayVersion`. The folder is in `HKCU\Software\ExcelToKMLPro`, value `InstallDir`
  (default `%LOCALAPPDATA%\ExcelToKMLPro`).
- **Program:** `ExcelToKML.exe`. It was `ExcelToKMLPro.exe` before 4.3.1, so look for both.
- **Install / update:** `ExcelToKML-Setup.exe /S`.
  - If the program is open, the silent installer closes it by force with `taskkill /F`, so
    unsaved work is lost.
  - After a silent install it **always opens the program**, because its own updater relies on
    that.
- **Uninstall:** `"<InstallDir>\Uninstall.exe" /S`. The registry `UninstallString` has no
  quotes, so the Toolkit builds the command itself. NSIS uninstallers return straight away, so
  wait until the registry entry is gone.
- **Own updater:** a few seconds after it opens, it reads `latest.json`, asks "Update now?",
  downloads, checks the SHA-256 and runs the installer with `/S`.

## Traverse & Level

Same pattern as Excel to KML.

- **Releases:** `github.com/Asjad-Mehmood/Traiverse`. Each release has `TraverseLevel-Setup.exe`,
  the same file again as `TraversePro-Setup.exe`, and `latest.json`.
- **Installed?** `HKCU\…\Uninstall\TraversePro`, value `DisplayVersion`. The folder is in
  `HKCU\Software\TraversePro`, value `InstallDir` (default `%LOCALAPPDATA%\TraversePro`).
- **Program:** `TraverseLevel.exe`, or `TraversePro.exe` in old copies.
- **Install / update:** `/S`. It closes an open copy by force and always opens the program
  afterwards.
- **Uninstall:** `"<InstallDir>\Uninstall.exe" /S`.
- **Web app:** the Toolkit card also has "Open the web app".

## Slope Calculator

- **Releases:** `github.com/Asjad-Mehmood/Slope-calculator-`, with `SlopeCalculator-Setup.exe`
  and `latest.json`.
- **Problem found:** the **v1.0.3 release has no `latest.json`.** The release run of
  30 October uploaded the installer, but the upload of `latest.json` failed. So copies of
  1.0.2 can't see 1.0.3. This needs fixing in Slope Calculator, not here. Until then, the
  Toolkit falls back to the GitHub release's own SHA-256 (the asset `digest`).
- **Installed?** `HKCU\…\Uninstall\SlopeCalculator`, value `DisplayVersion`; `InstallLocation`
  holds the folder (default `%LOCALAPPDATA%\SlopeCalculator`).
- **Program:** `SlopeCalculator.exe`.
- **Install / update:**
  - `/S` installs without opening the program. This is what the Toolkit wants.
  - `/S /UPDATE` opens it afterwards.
  - Either way, an open copy is closed by force.
- **Uninstall:** `QuietUninstallString` is given: `"<folder>\Uninstall.exe" /S`.
- **Web app:** `https://www.exceltokml.com/slope-calculation/app`.

## RoadPro (AutoCAD plugin)

- **Download:** `https://www.exceltokml.com/roadpro/RoadPro.zip`. It holds `RoadPro.lsp`
  (the plugin), `RP_PAVER.pat` (a hatch pattern RoadPro also writes itself) and `README.txt`.
- **Version:** only inside the file, on line 3 of `RoadPro.lsp`: `;;; Version : 3.4`. The
  website has it in `lib/roadpro.ts` too. The feed (T1) publishes it with the zip's SHA-256.
- **How it's installed today:** by hand. Copy `RoadPro.lsp` to a folder, run `APPLOAD`, then add
  it to the Startup Suite.
- **How the Toolkit will install it:** as an AutoCAD autoloader bundle,
  `%APPDATA%\Autodesk\ApplicationPlugins\RoadPro.bundle\` with a `PackageContents.xml` that
  loads `RoadPro.lsp` on start-up. That works in AutoCAD 2014 and newer, with no APPLOAD and
  no Startup Suite. Updating is a file swap, and AutoCAD loads the new one at its next start.
- **Is AutoCAD there?** `HKCU\Software\Autodesk\AutoCAD\R*\ACAD-*` keys. AutoCAD LT can't run
  LISP, so the card says "Needs full AutoCAD".
- **To check on a PC with AutoCAD (T8), because CI has no AutoCAD:**
  - Does AutoCAD's SECURELOAD warn about a bundle in `%APPDATA%`? If so, add the bundle folder
    to TRUSTEDPATHS, or install to `%ProgramData%` (which needs administrator rights).
  - Is a copy loaded by hand from the Startup Suite also loaded? The Startup Suite list is in
    `HKCU\Software\Autodesk\AutoCAD\R*\ACAD-*\Profiles\<profile>\Dialogs\Appload\Startup`. The
    Toolkit can spot an old `RoadPro.lsp` there and tell the user to remove it.

## Project Folder Manager

- **Download:** `https://www.exceltokml.com/project-folder-manager/Project_Folder_Manager.zip`.
  It holds `Project_Folder_Manager.exe`, `Project_Folder_Manager.hta`, `READ_ME.txt` and
  `dashboard_icon.ico`.
- **Version:** only inside the `.hta`, as `PROJECT FOLDER MANAGER  v6.2`. It's also in the
  website's `lib/folderManager.ts`.
- **How it's installed today:** unzip anywhere and double-click the `.exe`. It runs on Windows'
  own `mshta.exe`.
- **Settings:** `Project_Folder_Manager_config.txt` is kept **next to the `.hta`**. An update
  must keep that file; its READ_ME says "Update: replace only the .hta file".
- **How the Toolkit will install it:** unzip to
  `%LOCALAPPDATA%\Survey Toolkit\apps\Project Folder Manager\` and add a Start menu shortcut.
  To update, replace the four files and keep `Project_Folder_Manager_config.txt`.
- **Copies unzipped by hand** can be anywhere, so the Toolkit can't find them. The card offers
  "I already have it: choose its folder".

## Decisions from T0

1. **Per-user and no service.** No tool needs administrator rights, so neither does the Toolkit.
2. **Never install while the tool is open.** All three installers close an open copy by force.
   The Toolkit checks the running programs first and asks the user to close it.
3. **Automatic updates and "opens itself".** Excel to KML and Traverse & Level open after
   every silent install. For them, automatic updates (T4) run when the user opens the program
   from the Toolkit (update, then open) until those installers get `/NOLAUNCH` (PLAN.md,
   product change 1). Slope Calculator can update in the background now.
4. **The three programs' updaters stay as they are.** They use the same installer and the same
   `latest.json`, so if both updaters run, the result is the same.
5. **Feed (T1):** read the three programs' `latest.json` and GitHub release. Keep RoadPro and
   Project Folder Manager's version and SHA-256 in `lib/toolkit/tools.ts` on the website.
6. **Every download is checked against its SHA-256 before it runs.**
