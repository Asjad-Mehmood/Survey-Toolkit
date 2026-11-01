# Rules for this repository

The Survey Toolkit is a **separate test**. Keeping it separate is the first priority.

- Never change another repository (Excel to KML, Traverse & Level, Slope Calculator, RoadPro,
  Project Folder Manager, the website) as part of Toolkit work. If the Toolkit needs a product
  change, write it in docs/PLAN.md under "Product changes, after the test" and ask the owner.
- On the website, Toolkit code lives only in `app/toolkit-beta/`, `app/api/toolkit/`,
  `lib/toolkit/` and `components/toolkit/`, with new database tables named `Toolkit*` added by
  migrations that only add. Those pages are noindex, not in the sitemap and not in the menu.
- Toolkit releases are GitHub **pre-releases** with v0.x tags until the owner says launch.
- On a PC the Toolkit keeps its own files in `%LOCALAPPDATA%\Survey Toolkit`. It installs a
  program only with that program's official installer or download, checked against its SHA-256,
  and never edits another program's files.
- Never run a program's installer while that program is open: in silent mode the installers
  close it by force (docs/TOOLS.md).
- Merge only when the owner says "Merge". Don't tag a release unless the owner says so.
- No secrets in the repository.
