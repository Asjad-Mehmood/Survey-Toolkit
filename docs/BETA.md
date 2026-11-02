# The beta with real people (T9)

Three to five testers, about two weeks, on real PCs. The goal is to learn what GitHub's test
machines can't show: real networks, antivirus programs, AutoCAD, older PCs and people who have
never seen the Toolkit.

## 1. Before it starts (the owner)

Each step waits for the owner. Nothing here happens without them.

1. **Merge** the pull requests, in order: Survey-Toolkit #1, website #97, Survey-Toolkit #2, #3,
   #4, #5, #6. The website's new pages appear only at `/toolkit-beta` and `/toolkit-beta/admin`.
2. **Fix Slope Calculator's update file.** Release v1.0.3 has no `latest.json`, so PCs with 1.0.2
   don't see the update by themselves. The Toolkit updates it anyway, but the program's own check
   should agree: publish v1.0.4, or run v1.0.3's release job again.
3. **Publish the first beta, v0.5.0**: push the tag `v0.5.0` on `main`. The **Build and Release
   (beta)** workflow builds, tests, makes `SurveyToolkit-Setup.exe` and `latest.json`, and
   publishes a GitHub **pre-release** with `docs/releases/v0.5.0.md` as its notes.
4. **Add the testers** at `/toolkit-beta/admin` → Testers, with a note on each one's PC.
5. **Send the invitation** (section 7), with the link `https://www.exceltokml.com/toolkit-beta`.
6. **Halfway (about day 7): publish v0.5.1**, even with small changes, to see the Toolkit update
   itself on every tester's PC.

## 2. Testers and their PCs

At least one PC in each row. One PC can cover several rows.

| | What it shows |
| --- | --- |
| Windows 11 | the usual PC |
| Windows 10 (22H2) | the older Windows; WebView2 may need installing |
| A PC with **AutoCAD** (full, Civil 3D or Map 3D) | RoadPro loading in AutoCAD; SECURELOAD |
| A PC with tools **already installed** before the Toolkit | finding them, updating them |
| A **slow network** (phone hotspot or a site office) | downloads, progress, time-outs |
| A PC that is often **offline** | starting without the website, the kept tool list |
| An **antivirus program** other than Windows Defender | the unsigned installer; the installs it runs |
| A company PC with **restricted rights** | everything is per user, no administrator needed |

## 3. Each tester's checklist

Each tester goes through this once on each PC and tells us anything that isn't ✅. Admin shows
most of it already (PCs, versions, failures); the rest needs their eyes.

**Getting it**
- [ ] `/toolkit-beta` opens after signing in; the Download button gives `SurveyToolkit-Setup.exe`
- [ ] SmartScreen's warning: **More info → Run anyway** works (note the antivirus's reaction)
- [ ] The installer finishes; the Toolkit opens; Start menu and desktop shortcuts are there

**Signing in**
- [ ] With email and password, **or** Sign in with the browser (Google)
- [ ] Closing and opening the Toolkit again: still signed in, also with no internet

**Home**
- [ ] Tools already on the PC are found, with the right versions
- [ ] Install a tool that isn't there; it opens from **Open**
- [ ] **Update** a tool that is behind (if none is, we arrange one)
- [ ] With a tool open, Update says to close it first and changes nothing
- [ ] **Uninstall** a tool, then install it again
- [ ] Project Folder Manager: its settings are still there after an update

**The workspace**
- [ ] Excel to KML, Traverse & Level and Slope Calculator open inside the Toolkit, **already signed
      in**
- [ ] Switching between them keeps each where it was; the app grid and Ctrl+1 to Ctrl+4 work
- [ ] A file saved in a web app shows in the account on the website

**Updates**
- [ ] **Start with Windows** on: after a restart the Toolkit is in the tray, no window
- [ ] Closing the window keeps it in the tray; the tray icon opens it; Quit closes it
- [ ] When v0.5.1 is published (day 7): the Toolkit offers it, updates itself and opens again
- [ ] A tool update arriving with nobody pressing anything, and its notification
- [ ] Excel to KML or Traverse & Level behind: opening it from the Toolkit updates it first

**At the end**
- [ ] Windows Settings → Apps → Survey Toolkit → Uninstall: the Toolkit goes, the tools stay

**When something goes wrong**, the tester sends what they saw (a screenshot helps) and the file
`%LOCALAPPDATA%\Survey Toolkit\toolkit.log`, which lists every install, update and uninstall with
its reason. It holds no passwords or files.

## 4. AutoCAD (by hand, a PC with AutoCAD)

GitHub's machines have no AutoCAD, so this is checked here only.

- [ ] Install RoadPro from the Toolkit while AutoCAD is **closed**; start AutoCAD: RoadPro's
      commands are there without APPLOAD
- [ ] **SECURELOAD** (1 by default): does AutoCAD ask before loading from
      `%APPDATA%\Autodesk\ApplicationPlugins\RoadPro.bundle`? Note the exact message. If it asks
      every time, the fix is a trusted location, written up as a product change, not done silently
- [ ] With AutoCAD **open**, Update RoadPro: the Toolkit says to close AutoCAD first
- [ ] An old RoadPro in the **Startup Suite** as well: the Toolkit's note says how to remove it,
      and after that only one RoadPro loads
- [ ] AutoCAD LT: the Toolkit says RoadPro needs full AutoCAD and doesn't offer it

## 5. What the owner watches

Daily, at `/toolkit-beta/admin`:

- **Activity → Failed:** each failure with its reason. A failure on two PCs, or one that comes
  back after a retry, gets a fix and a new beta release.
- **PCs:** a PC not seen for 3 days (the Toolkit isn't running or can't reach the website); tools
  still marked older a day after a release (updates aren't arriving).
- **Overview:** updates in 30 days, and how many were automatic.

Each problem found goes on the list in section 6 with what was done about it.

## 6. Found during the beta

| Date | PC | What happened | What we did |
| --- | --- | --- | --- |
| | | | |

## 7. The invitation (draft)

> **Subject: You're invited to test the Survey Toolkit**
>
> Hello [name],
>
> Thank you for agreeing to test the Survey Toolkit. It's one Windows program that installs and
> updates all our survey tools for you: Excel to KML, RoadPro, Traverse & Level, Project Folder
> Manager and Slope Calculator. The web apps open inside it, already signed in.
>
> **Get it:** https://www.exceltokml.com/toolkit-beta (sign in with your Excel to KML account,
> [email]).
>
> Windows may warn that it doesn't know the program, because it isn't code-signed yet. Choose
> **More info**, then **Run anyway**.
>
> Please use it as you normally would for about two weeks. The checklist is on the page; anything
> odd, slow or confusing is worth a line, with a screenshot if you can, through the page's
> **Report a problem** button.
>
> To see that updates reach every PC, the Toolkit tells us this PC's name, its Windows version
> and the versions of our tools on it, and each install or update. Nothing else, and none of
> your files.
>
> Thank you,
> [your name]

## 8. When the beta is done (go to T10, or not)

The owner decides. To go ahead to the launch (T10), all of these should hold:

- every row of section 2 was covered by at least one PC;
- no open failure in Admin that happened on more than one PC;
- v0.5.1 reached every PC that was running, by itself;
- at least one tool update reached the testers with nobody pressing anything;
- RoadPro loads in AutoCAD from the bundle, and what SECURELOAD does is known;
- no tester lost settings or files.

If not, fix and run another week, or stop the test: the Toolkit's folders and tables come out
(docs/PLAN.md, T10).
