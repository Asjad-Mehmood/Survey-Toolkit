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
| Risk | Power is added in steps: look only (T2), install on a click (T3), automatic (T5) |

## Phases

Each phase is one pull request, merged only when the owner says "Merge".

### T0: Research

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
- `GET/POST/DELETE /api/toolkit/testers`: the beta list, admins only (the Admin screen is T6).

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
- **Left for a PC with AutoCAD (T9):** whether SECURELOAD asks about a bundle in `%APPDATA%`.

### T4: Workspace, every web app in one window

The Toolkit becomes a workspace, like the Microsoft 365 app.

**What it has:**
- **A sidebar** with **Home** (the Tools page) and the three web apps: **Excel to KML**
  (`/app`), **Traverse & Level** (`/traverse/app`) and **Slope Calculator**
  (`/slope-calculation/app`).
- **Each app inside the window:** it opens in the Toolkit's own window (Microsoft Edge WebView2,
  built into Windows 10 and 11). It stays open in the background when you switch, like a tab.
- **Google's app grid** in the header, and **Ctrl+1 to Ctrl+4**, to jump between them.
- **Signed in already:** the Toolkit asks the website for a **single-use code** (POST
  `/api/toolkit/handoff`, testers only), good for 60 seconds and only for those three
  addresses. The window opens it and is signed in with a session of its own. The long-lived
  sign-in never goes into an address. If there's no code (offline), the app shows its own
  sign-in.
- **Each app's toolbar:** Back, Reload, Open in your browser, and **Windows app** when that
  tool's program is installed.
- **Links off the website** open in the browser.
- **The last app** opened comes back next time.
- **Signing out** clears every app window's sign-in. The uninstaller removes the windows'
  browser data.

**Left out on purpose:** RoadPro (it runs inside AutoCAD) and Project Folder Manager (a Windows
HTML application). They stay on Home.

**The live website** gets no app switcher in this phase, to keep the test separate. That can come
at launch (T10).

**Done when:** the three apps work inside the Toolkit, signed in, on a test PC, and the Windows
check shows a web app drawn inside the window.

### T5: Automatic updates (v0.4)

- Checks when it starts and every 4 hours while open.
- **Start with Windows**, in the tray. Off by default.
- Each tool can be set to **Automatic** or **Ask me**.
- A notification after each update, for example "RoadPro updated to 3.5".
- **Excel to KML and Traverse & Level open themselves after a silent install**, so until they
  have the `/NOLAUNCH` switch (see "Product changes" below), their automatic updates run only
  when the user opens them from the Toolkit. Opening them then is what the user wanted anyway.

**Done when:** a new version of any tool reaches a test PC with nobody pressing anything.

**As built (v0.4):**

- **When:** as the Toolkit opens (once a tester is signed in), every 4 hours while it runs (in
  the tray too), from the tray's **Check for updates now**, and with **Check again** on Home.
  Each check reads the feed, looks on the PC, then updates every tool that is due, one at a time,
  with the same download, SHA-256 check and installer as the Update button.
- **Automatic** (the default) **or Ask me**, per tool, in the new **Updates** section on Home.
  Only tools that are installed are updated: nothing is ever installed by itself.
- **A tool that is open** is never updated. Nothing is shown on its card; it is tried again
  after 30 minutes. The card says "Updates by itself when it isn't open".
- **A failed update** is tried at the next check. After 3 failures at the same version the
  Toolkit stops, sends one notification, and leaves it to the Update button.
- **Excel to KML and Traverse & Level** (set to Automatic): opening them from the Toolkit (their
  card's Open, or the workspace's Windows app button) updates them first, and their installer
  opens the new version.
- **Notifications** come from the Toolkit's tray icon, so Windows 10 and 11 show them as ordinary
  notifications: "Slope Calculator updated to 1.0.3", or "Updated: …" for several.
- **The tray icon** (the Windows program's own, `windows/runner/tray.cpp`): click to open; right
  click for Open, Check for updates now and Quit.
- **Start with Windows and keep running in the tray**, off by default: a `SurveyToolkit` value
  under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` that starts it with `--tray` (no
  window). With it on, closing the window keeps the Toolkit in the tray, and says so the first
  time. Opening the Toolkit again shows the window. The uninstaller removes the value.
- **The Toolkit's own update** is looked for with each check too, and asked about once per
  version, with a notification in case the window is hidden.
- **The website is told** of each automatic update (`message: "automatic"`) for Admin (T6).
- **Tests:** the rules, the scheduler, retries, giving up, Ask me, open-to-update, the Updates
  section and the switch. The Windows check runs the automatic update once (`--auto-update`) on a
  real PC: Slope Calculator 1.0.2 is updated by itself, Excel to KML and a tool set to Ask me wait,
  nothing opens; then Start with Windows, the hidden start, the second start showing the window,
  and closing into the tray.

### T6: Admin

A separate **Toolkit (beta)** tab in the website's Admin:

- testers: add and remove;
- PCs: each tester's PCs and the tool versions on each;
- updates done and failed, with the reason;
- Toolkit downloads.

**As built (website PR #97):** a page of its own, **`/toolkit-beta/admin`**, in the main Admin's
frame and sign-in, rather than a tab inside `app/admin`, so the main Admin is unchanged and the
test can be removed without touching it. Admins only; signed out goes to the sign-in, anyone else
gets "not found"; never indexed. A link to it from the main Admin can come at launch (T10).

- **Overview:** testers, PCs seen in 7 days, updates and failures in 30 days (and how many were
  automatic), Toolkit downloads (from its GitHub releases), each tool's latest version against
  the testers' PCs, the latest failures.
- **Testers:** add (with a note) and remove; whether they have an account yet, their PCs, last
  sign-in, who added them.
- **PCs:** Windows, Toolkit and tool versions per PC (older ones marked), last seen, the PC's own
  activity; forget a PC.
- **Activity:** the newest 300 events, filtered by failed, automatic, updated, installed,
  uninstalled and tool, with the reason.
- `GET /api/toolkit/admin` and `DELETE /api/toolkit/admin?device=` (admins only); no new tables.

### T7: Automatic tests

On GitHub's Windows machines, on every change:

1. install the Toolkit;
2. install all five tools through it;
3. install an older version of one tool and check that the Toolkit updates it;
4. give it a wrong SHA-256 and check that it refuses;
5. keep a tool open and check that it waits;
6. uninstall everything and check that the PC is clean.

Screenshots of each step are kept as an artifact. There are also unit tests for the feed and
status logic.

### T8: Hidden beta page and the front page

- `/toolkit-beta`: a product page and a Download button, for testers only.
- `/toolkit-beta/home-options`: the five animated front-page options, built to the brief. They
  have a Pause button, real versions read from the feed, reduced motion and a phone layout. The
  owner picks one.

### T9: Beta with real people

- 3 to 5 testers, for about 2 weeks.
- Test PCs: Windows 10 and 11, a PC with AutoCAD, a slow network, offline, and an antivirus
  program.
- A checklist like Slope Calculator's TESTING.md, plus the failure list in Admin.

### T10: Launch, only when the owner says so

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
| Excel to KML and Traverse open themselves after a silent update | Automatic updates for them happen only when opened from the Toolkit, until `/NOLAUNCH` exists (T5) |
| No code signing | Every download is checked by SHA-256. Signing comes before a public launch. |
| RoadPro can't be tested in CI (no AutoCAD) | Tested by hand on a PC with AutoCAD (T9) |
| An old RoadPro in the AutoCAD Startup Suite loads as well as the new one | The Toolkit looks for it and tells the user how to remove it (T3) |
| Two updaters (the program's own and the Toolkit) | Same installer and same `latest.json`, so the result is the same. Product change 2 tidies it up. |
