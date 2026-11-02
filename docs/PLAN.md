# Survey Toolkit: plan

**Goal:** one program a surveyor downloads once. They sign in with their exceltokml.com account,
install any of the five tools with one click, and from then on every tool updates itself when a
new version is published.

**Approach: a separate test.** If the test is stopped, deleting this repository and the
website's Toolkit folders and tables leaves everything exactly as before.

## Separation

| Area | Kept separate by |
| --- | --- |
| Code | This repository only. Nothing is added to the five product repositories. |
| Website pages | Only under `/toolkit-beta`: noindex, not in the sitemap or menu, testers only |
| Website API | Only under `/api/toolkit/*`. Existing routes are not changed. |
| Database | Three tables of its own (`toolkit_testers`, `toolkit_devices`, `toolkit_events`), created on first use like `slope_jobs`: no migration, no other table changed |
| Download counts | Their own type, `toolkit` |
| Users | A beta allowlist, managed in Admin. Everyone else sees "The beta is closed". |
| Releases | GitHub **pre-releases**, v0.x. The products' "latest" links never change. |
| On the PC | `%LOCALAPPDATA%\Survey Toolkit`. Products are installed with their official installers, checked by SHA-256. |
| Front page | The animated options are previewed on `/toolkit-beta/home-options`. The real home page is unchanged until launch. |
| Risk | Power is added in steps: look only (T2), install on a click (T3), automatic (T4) |

## Phases

Each phase is one pull request, merged only when the owner says "Merge".

### T0: Research (this phase)

For each tool: how to find it on a PC, install it, update it, open it and remove it. Done in
[TOOLS.md](TOOLS.md), and checked on GitHub's Windows machines by `tool/probe_tools.ps1` (the
**Probe** workflow): it downloads every tool, checks its SHA-256, installs it silently, reads the
installed version, and uninstalls it again.

**Done when:** the Probe workflow passes and TOOLS.md has no open questions except those that
need a real PC (AutoCAD).

### T1: Version feed on the website

- `GET /api/toolkit/feed`: all five tools in one JSON file. For each: id, name, platform,
  latest version, release date, download URL, size, SHA-256, release notes link.
  - The three Windows programs come from their own `latest.json` and GitHub release, cached for
    10 minutes.
    If GitHub's API can't be read, `latest.json` alone still gives the version, SHA-256 and
    the installer's address.
  - RoadPro and Project Folder Manager: the version from the website's `lib/roadpro.ts` and
    `lib/folderManager.ts`. The server downloads each zip and hashes it (kept for an hour), so
    there is nothing to update by hand.
  - A tool that can't be checked gets no download, only a problem.
- `POST /api/toolkit/event`: the Toolkit reports installed, updated or failed, with the reason.
  Stored in `ToolkitEvent`.
- `GET /api/toolkit/me`: is this account a tester? Uses the same sign-in token as Slope
  Calculator. Admins always are.
- `GET/POST/DELETE /api/toolkit/testers`: the beta list, admins only (the Admin screen is T5).

Built in website PR #97.

**Done when:** the feed is right for all five tools (tests), and the website's existing tests
still pass with no change to existing routes.

### T2: The Toolkit program, look only (v0.1)

A Flutter Windows program reusing Slope Calculator's sign-in, theme and self-update code.

- Sign in first. Testers only.
- **Tools** page: a card per tool with its name, platform, **installed version → latest
  version**, a status (*Not installed*, *Up to date*, *Update available*), release notes and
  **Open**.
- Install and Update buttons open the official download page. **Nothing on the PC is changed.**
- The Toolkit updates itself, from its own pre-releases.

**Done when:** testers see the right status for every tool on their own PCs.

**As built:** this repository's Flutter program. The sign-in comes first, then
`/api/toolkit/me`, then the Tools page.

- **What is installed:** read with `reg.exe` and from the files under AppData.
- **The tool list:** the website's feed, with a built-in list as a fallback, so the Toolkit can
  look on the PC before it has ever reached the website.
- **Reports:** each check sends the PC and its installed versions to `/api/toolkit/event`.
- **Self-update:** from the Toolkit's own pre-releases.
- **Tests:** 54 automatic tests, including every screen at 5 sizes × 3 text sizes × light and
  dark.
- **The Windows check:** installs the Toolkit, installs the real tools from their official
  downloads, and checks that the Toolkit finds each one with the right version. It does this with
  `SurveyToolkit.exe --detect=<file>`, which looks, writes JSON and closes.

### T3: Install and update on a click (v0.2)

- Download to `%LOCALAPPDATA%\Survey Toolkit\downloads`, check the SHA-256 (refuse if it
  differs), then run the official installer silently.
- If the tool is open: "Close Excel to KML to update" and wait. The installers would close it by
  force (TOOLS.md).
- **RoadPro:** install as an AutoCAD bundle, so AutoCAD loads it by itself with no APPLOAD step.
- **Project Folder Manager:** unzip into the Toolkit's folder, keeping the user's settings file,
  and add a Start menu shortcut.
- If anything fails, the old version stays and the card says why. A log file is kept for support.
- **Uninstall** on each card, using the tool's own uninstaller.

**Done when:** every tool installs, updates and uninstalls cleanly on a test PC and in the
Windows CI test.

**As built:** `lib/src/toolkit/installer.dart`, with the Install, Update and Uninstall buttons and a
progress bar on each card. One job runs at a time, and each job is reported to
`/api/toolkit/event`.

- **Download addresses:** only `www.exceltokml.com` and `github.com/Asjad-Mehmood/…/releases/download/…`.
- **Files inside a zip:** they can't reach outside their folder.
- **Settings:** the settings file in `keep` is never overwritten.
- **Tests:** 86 automatic tests.
- **The Windows check:** builds a feed from the real downloads. The Toolkit then installs all
  five tools, updates Slope Calculator 1.0.2 to the latest, refuses while Slope Calculator is
  open, refuses a wrong SHA-256, and finds every version. It removes RoadPro and Project Folder
  Manager, keeping the settings file.
- **Left for a PC with AutoCAD (T8):** whether SECURELOAD asks about a bundle in `%APPDATA%`.

### T4: Automatic updates (v0.3)

- Checks when it starts and every 4 hours while open.
- **Start with Windows**, in the tray. Off by default.
- Each tool can be set to **Automatic** or **Ask me**.
- A notification after each update, for example "RoadPro updated to 3.5".
- **Excel to KML and Traverse & Level open themselves after a silent install**, so until they
  have the `/NOLAUNCH` switch (see "Product changes" below), their automatic updates run only
  when the user opens them from the Toolkit. Opening them then is what the user wanted anyway.

**Done when:** a new version of any tool reaches a test PC with nobody pressing anything.

### T5: Admin

A separate **Toolkit (beta)** tab in the website's Admin:

- testers: add and remove;
- PCs: each tester's PCs and the tool versions on each;
- updates done and failed, with the reason;
- Toolkit downloads.

### T6: Automatic tests

On GitHub's Windows machines, on every change:

1. install the Toolkit;
2. install all five tools through it;
3. install an older version of one tool and check that the Toolkit updates it;
4. give it a wrong SHA-256 and check that it refuses;
5. keep a tool open and check that it waits;
6. uninstall everything and check that the PC is clean.

Screenshots of each step are kept as an artifact. There are also unit tests for the feed and
status logic.

### T7: Hidden beta page and the front page

- `/toolkit-beta`: a product page and a Download button, for testers only.
- `/toolkit-beta/home-options`: the five animated front-page options, built to the brief. They
  have a Pause button, real versions read from the feed, reduced motion and a phone layout. The
  owner picks one.

### T8: Beta with real people

- 3 to 5 testers, for about 2 weeks.
- Test PCs: Windows 10 and 11, a PC with AutoCAD, a slow network, offline, and an antivirus
  program.
- A checklist like Slope Calculator's TESTING.md, plus the failure list in Admin.

### T9: Launch, only when the owner says so

If the beta went well:

- the chosen front page goes on the real home page;
- the Toolkit becomes the main Download button;
- the product changes below are made;
- the "beta" label is removed.

If not, the Toolkit folders and tables are removed.

## Product changes, after the test

These are not part of the test. Each one is listed here and asked for before it is made.

1. **`/NOLAUNCH`** in the Excel to KML and Traverse & Level installers, so a silent update from
   the Toolkit doesn't open the program. Slope Calculator already behaves like this: it reopens
   only with `/UPDATE`.
2. **"Managed by the Toolkit"** in the three programs' own update checks, so they leave
   updating to the Toolkit when it is installed and two updaters don't offer the same update.
3. **A `latest.json` for RoadPro and Project Folder Manager**, published with each new zip.
4. **Code signing**, before a public launch, so SmartScreen and antivirus programs trust the
   Toolkit.

## Risks

| Risk | What we do |
| --- | --- |
| A program open during an update is closed by force | The Toolkit checks first and waits (T3) |
| Excel to KML and Traverse open themselves after a silent update | Automatic updates for them happen only when opened from the Toolkit, until `/NOLAUNCH` exists (T4) |
| No code signing | Every download is checked by SHA-256. Signing comes before a public launch. |
| RoadPro can't be tested in CI (no AutoCAD) | Tested by hand on a PC with AutoCAD (T8) |
| An old RoadPro in the AutoCAD Startup Suite loads as well as the new one | The Toolkit looks for it and tells the user how to remove it (T3) |
| Two updaters (the program's own and the Toolkit) | Same installer and same `latest.json`, so the result is the same. Product change 2 tidies it up. |
