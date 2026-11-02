# The Toolkit on a clean Windows PC (GitHub's Windows machines, no graphics card):
#   1. install the Toolkit silently and check its files, shortcuts and Settings > Apps entry;
#   2. on a PC with none of the tools, the Toolkit finds none of them;
#   3. a feed like the website's, from the tools' official downloads;
#   4. the Toolkit installs all of them (--install, the same code as the Install button);
#   5. it updates an older Slope Calculator (1.0.2) to the latest;
#   6. with a tool open, it asks to close it and does nothing;
#   7. a download with the wrong SHA-256 is refused and never run;
#   8. it finds every one, with the right version and the program to open;
#   9. it removes RoadPro and Project Folder Manager, keeping the settings file;
#  10. the automatic update (T5): an older Slope Calculator is updated with nobody pressing anything;
#      Excel to KML waits until it is opened from the Toolkit, a tool set to Ask me waits too;
#  11. Start with Windows: the Run value; started with --tray only the tray icon, no window; a second
#      start shows the window; closing it keeps the Toolkit running in the tray (a screenshot);
#  12. open the Toolkit: a drawn window with the sign-in, a screenshot, one copy on a second start;
#  13. the workspace: Slope Calculator's web app inside the Toolkit's window (WebView2), a screenshot;
#  14. the Toolkit updates itself: the new installer with /S /UPDATE while it is open (as its
#      self-updater runs it) closes it, installs, and opens the new version; Start with Windows stays;
#  15. the Toolkit removes the last two tools it installed, Excel to KML and Traverse & Level;
#  16. uninstall the Toolkit: its folder, entry, Start with Windows, the web apps' browser data, its
#      sign-in and its log go; the tools stay;
#  17. Slope Calculator is removed with its own uninstaller, and the PC is clean: nothing in
#      Settings > Apps, no program files, no shortcuts, only the user's own Project Folder Manager
#      settings file kept on purpose.
# Every check goes on the run's summary page as a checklist, with a screenshot at each step that
# shows something (saved in the shots folder, kept as the run's artifact).
#   pwsh tool/windows_check.ps1 installer\SurveyToolkit-Setup.exe shots
param([Parameter(Mandatory)] [string] $Installer, [string] $Shots = 'shots')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$home_ = Join-Path $env:LOCALAPPDATA 'Survey Toolkit'
$dir = Join-Path $home_ 'Program'
$exe = Join-Path $dir 'SurveyToolkit.exe'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SurveyToolkit'
$work = Join-Path $env:RUNNER_TEMP 'toolkit-check'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$api = @{ 'User-Agent' = 'survey-toolkit-check'; 'Accept' = 'application/vnd.github+json' }
if ($env:GITHUB_TOKEN) { $api['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

New-Item -ItemType Directory -Force -Path $Shots | Out-Null
$script:shot = 0
# the checklist on the run's summary page
function Summary([string] $line) { if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $line -Encoding utf8 } }
function Step([string] $title) { Write-Host "`n== $title"; Summary "`n### $title`n" }
function Check($ok, $what) {
  if (-not $ok) { Summary "- :x: **FAILED: $what**"; throw "FAILED: $what" }
  Write-Host "ok  $what"
  Summary "- :white_check_mark: $what"
}
# something to know that isn't the Toolkit's to fix (another program's own behaviour)
function Note([string] $what) { Write-Host "note  $what"; Summary "- :warning: $what" }
Summary '## Survey Toolkit on a clean Windows PC'
function WaitFor([scriptblock] $test, [int] $seconds) {
  for ($i = 0; $i -lt $seconds * 2; $i++) { if (& $test) { return $true }; Start-Sleep -Milliseconds 500 }
  return $false
}
# wait for the process itself only: Start-Process -Wait would also wait for a program it opens
function RunAndWait([string] $file, [string[]] $arguments) {
  $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit(300000)) { throw "$file did not finish within 5 minutes" }
  return $p.ExitCode
}
# a screenshot of the whole screen, numbered in step order; unless -Plain, it must show a drawn window
function Shot([string] $name, [string] $what, [switch] $Plain) {
  $script:shot++
  $file = Join-Path $Shots ('{0:D2}-{1}.png' -f $script:shot, $name)
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
  [System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $colours = @{}
  for ($x = 0; $x -lt $screen.Width; $x += 23) { for ($y = 0; $y -lt $screen.Height; $y += 19) { $colours[$bmp.GetPixel($x, $y).ToArgb()] = 1 } }
  Write-Host "screenshot: $file ($($screen.Width)x$($screen.Height), $($colours.Count) colours)"
  Summary "- :camera: ``$(Split-Path $file -Leaf)``: $what"
  if (-not $Plain) { Check ($colours.Count -gt 20) "$what (the screenshot shows a drawn window)" }
}
function Detect([string] $name) {
  $out = Join-Path $work "$name.json"
  Remove-Item $out -ErrorAction SilentlyContinue
  $code = RunAndWait $exe @("--detect=$out")
  Check ($code -eq 0 -and (Test-Path $out)) "--detect ($name) ran and wrote its result"
  $j = Get-Content $out -Raw | ConvertFrom-Json
  Write-Host (Get-Content $out -Raw)
  return $j
}

Step '1. Install the Toolkit'
# 1. install
$code = RunAndWait $Installer @('/S')
Check ($code -eq 0) 'the installer finished (exit 0)'
Check (Test-Path $exe) 'installed to %LOCALAPPDATA%\Survey Toolkit\Program'
foreach ($f in 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'Uninstall.exe') {
  Check (Test-Path (Join-Path $dir $f)) "has $f"
}
Check ((Get-ItemProperty $key).DisplayName -eq 'Survey Toolkit') 'listed in Settings > Apps as "Survey Toolkit"'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Survey Toolkit\Survey Toolkit.lnk')) 'Start menu shortcut'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Survey Toolkit.lnk')) 'desktop shortcut'
Shot 'installed' 'the desktop after installing, with the Toolkit''s shortcut' -Plain

Step '2. A PC with none of the tools'
# 2. a PC with none of the tools
$none = Detect 'none'
foreach ($id in 'excel-to-kml', 'roadpro', 'traverse', 'folder-manager', 'slope') {
  Check ($null -eq $none.tools.$id.version) "finds no $id on a clean PC"
}

Step '3. A feed like the website''s, from the official downloads'
# 3. a feed like the website's, from the tools' official downloads (the website's feed may not be
#    live; the Toolkit reads both the same way)
function Sha([string] $f) { (Get-FileHash -Algorithm SHA256 -Path $f).Hash.ToLower() }
$tools = @()
$want = @{}
$programs = @(
  @{ id = 'excel-to-kml'; name = 'Excel to KML'; repo = 'Asjad-Mehmood/kml-convertor'; file = 'ExcelToKML-Setup.exe'; key = 'ExcelToKMLPro'; exe = @('ExcelToKML.exe', 'ExcelToKMLPro.exe'); opens = $true },
  @{ id = 'traverse'; name = 'Traverse & Level'; repo = 'Asjad-Mehmood/Traiverse'; file = 'TraverseLevel-Setup.exe'; key = 'TraversePro'; exe = @('TraverseLevel.exe', 'TraversePro.exe'); opens = $true },
  @{ id = 'slope'; name = 'Slope Calculator'; repo = 'Asjad-Mehmood/Slope-calculator-'; file = 'SlopeCalculator-Setup.exe'; key = 'SlopeCalculator'; exe = @('SlopeCalculator.exe'); opens = $false }
)
foreach ($p in $programs) {
  $rel = Invoke-RestMethod -Headers $api -Uri "https://api.github.com/repos/$($p.repo)/releases/latest"
  $asset = $rel.assets | Where-Object { $_.name -eq $p.file } | Select-Object -First 1
  $f = Join-Path $work "feed-$($p.file)"
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $f
  $v = $rel.tag_name.TrimStart('v')
  $want[$p.id] = $v
  $tools += @{ id = $p.id; name = $p.name; platform = 'Windows'; page = 'https://www.exceltokml.com/'; version = $v
    download = @{ url = $asset.browser_download_url; file = $p.file; size = $asset.size; sha256 = (Sha $f) }
    # as the website's feed says (lib/toolkit/tools.ts): which installers open the program afterwards
    install = @{ kind = 'installer'; registryKey = $p.key; exe = $p.exe; silentArgs = @('/S'); opensAfterSilentInstall = $p.opens } }
}
$zips = @(
  @{ id = 'roadpro'; name = 'RoadPro'; url = 'https://www.exceltokml.com/roadpro/RoadPro.zip'; file = 'RoadPro.zip'
     inner = 'RoadPro.lsp'; pattern = 'Version\s*:\s*([0-9.]+)'
     install = @{ kind = 'autocad-bundle'; files = @('RoadPro.lsp', 'RP_PAVER.pat', 'README.txt'); keep = @(); main = 'RoadPro.lsp' } },
  @{ id = 'folder-manager'; name = 'Project Folder Manager'; url = 'https://www.exceltokml.com/project-folder-manager/Project_Folder_Manager.zip'; file = 'Project_Folder_Manager.zip'
     inner = 'Project_Folder_Manager.hta'; pattern = 'PROJECT FOLDER MANAGER\s+v([0-9.]+)'
     install = @{ kind = 'zip'; files = @('Project_Folder_Manager.exe', 'Project_Folder_Manager.hta', 'READ_ME.txt', 'dashboard_icon.ico'); keep = @('Project_Folder_Manager_config.txt'); main = 'Project_Folder_Manager.exe' } }
)
foreach ($z in $zips) {
  $f = Join-Path $work "feed-$($z.file)"
  Invoke-WebRequest -Uri $z.url -OutFile $f
  $x = Join-Path $work "x-$($z.id)"
  Expand-Archive -Path $f -DestinationPath $x -Force
  $v = [regex]::Match((Get-Content (Join-Path $x $z.inner) -Raw), $z.pattern).Groups[1].Value
  $want[$z.id] = $v
  $tools += @{ id = $z.id; name = $z.name; platform = 'Windows'; page = 'https://www.exceltokml.com/'; version = $v
    download = @{ url = $z.url; file = $z.file; size = (Get-Item $f).Length; sha256 = (Sha $f) }; install = $z.install }
}
$feed = Join-Path $work 'feed.json'
@{ schema = 1; tools = $tools } | ConvertTo-Json -Depth 6 | Set-Content -Path $feed -Encoding utf8

function Toolkit([string] $verb, [string] $id, [string] $feedFile = $feed) {
  $out = Join-Path $work "result-$verb-$id.json"
  Remove-Item $out -ErrorAction SilentlyContinue
  $code = RunAndWait $exe @("--$verb=$id", "--feed=$feedFile", "--result=$out")
  $r = Get-Content $out -Raw | ConvertFrom-Json
  Write-Host "  [$verb $id] exit $code : $($r.message)"
  return $r
}
function StopTools { foreach ($n in 'ExcelToKML', 'TraverseLevel', 'SlopeCalculator') { Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } }

Step '4. The Toolkit installs every tool'
# 4. the Toolkit installs every tool, from nothing
foreach ($id in 'excel-to-kml', 'traverse', 'roadpro', 'folder-manager') {
  $r = Toolkit 'install' $id
  Check ($r.ok -and $r.version -eq $want[$id]) "the Toolkit installs $id $($want[$id])"
  if ($id -in 'excel-to-kml', 'traverse') {
    # Excel to KML and Traverse & Level open themselves after a silent install
    Start-Sleep -Seconds 6
    Shot "installed-$id" "$id $($want[$id]), installed by the Toolkit and opened by its own installer" -Plain
  }
  StopTools
}
$xml = Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\RoadPro.bundle\PackageContents.xml'
Check ((Test-Path $xml) -and ((Get-Content $xml -Raw) -match 'LoadOnAutoCADStartup="True"')) 'RoadPro is an AutoCAD bundle that loads at start-up'
$pfm = Join-Path $home_ 'apps\Project Folder Manager'
Check (Test-Path (Join-Path $pfm 'Project_Folder_Manager.hta')) 'Project Folder Manager is in the Toolkit''s folder'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Survey Toolkit\Project Folder Manager.lnk')) 'Project Folder Manager has a Start menu shortcut'
Check (@(Get-ChildItem (Join-Path $home_ 'downloads') -File -ErrorAction SilentlyContinue).Count -eq 0) 'no downloads left behind'

Step '5. An update: Slope Calculator 1.0.2 to the latest'
# 5. an update: an older Slope Calculator (its v1.0.2 installer), then the Toolkit brings it up to date
$old = Join-Path $work 'SlopeCalculator-Setup-1.0.2.exe'
Invoke-WebRequest -Uri 'https://github.com/Asjad-Mehmood/Slope-calculator-/releases/download/v1.0.2/SlopeCalculator-Setup.exe' -OutFile $old
$null = RunAndWait $old @('/S')
$before = Detect 'before-update'
Check ($before.tools.slope.version -eq '1.0.2') 'Slope Calculator 1.0.2 to start from'
$r = Toolkit 'install' 'slope'
Check ($r.ok -and $r.version -eq $want['slope']) "the Toolkit updates Slope Calculator to $($want['slope'])"

Step '6. A tool that is open is never installed over'
# 6. a tool that is open is never installed over
$p = Start-Process -FilePath (Join-Path $env:LOCALAPPDATA 'SlopeCalculator\SlopeCalculator.exe') -PassThru
Start-Sleep -Seconds 6
$r = Toolkit 'install' 'slope'
Check ($r.blocked -and $r.message -like 'Close Slope Calculator first*') 'with Slope Calculator open, the Toolkit asks to close it and does nothing'
$p.Refresh()
Check (-not $p.HasExited) 'Slope Calculator was left open'
Shot 'tool-open' "Slope Calculator $($want['slope']) open (after the Toolkit's update); the Toolkit left it alone" -Plain
StopTools

Step '7. A download with the wrong SHA-256 is never run'
# 7. a download that doesn't match its SHA-256 is never run
$r = Toolkit 'uninstall' 'traverse'
Check $r.ok 'the Toolkit uninstalls Traverse & Level with its own uninstaller'
$bad = Get-Content $feed -Raw | ConvertFrom-Json
($bad.tools | Where-Object { $_.id -eq 'traverse' }).download.sha256 = ('0' * 64)
$badFeed = Join-Path $work 'feed-bad.json'
$bad | ConvertTo-Json -Depth 6 | Set-Content -Path $badFeed -Encoding utf8
$r = Toolkit 'install' 'traverse' $badFeed
Check ((-not $r.ok) -and $r.message -like '*SHA-256*') 'a wrong SHA-256 is refused'
Check (-not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TraversePro')) 'and Traverse & Level was not installed'
$r = Toolkit 'install' 'traverse'
Check $r.ok 'installed again with the right SHA-256'
Start-Sleep -Seconds 3
StopTools

Step '8. The Toolkit finds every tool, with the right versions'
# 8. the Toolkit finds them all, with the right versions
$all = Detect 'all'
foreach ($id in $want.Keys) {
  Check ($all.tools.$id.version -eq $want[$id]) "finds $id $($want[$id]) (found: $($all.tools.$id.version))"
}
foreach ($id in 'excel-to-kml', 'traverse', 'slope', 'folder-manager') {
  Check ($all.tools.$id.program -and (Test-Path $all.tools.$id.program)) "knows the program to open for $id"
}
Check ($all.tools.roadpro.note -eq 'AutoCAD not found on this PC') 'says AutoCAD is not on this PC (RoadPro needs it)'

Step '9. Removing RoadPro and Project Folder Manager'
# 9. removing RoadPro and Project Folder Manager, keeping its settings
Set-Content -Path (Join-Path $pfm 'Project_Folder_Manager_config.txt') -Value 'ROOT=D:\Projects'
$r = Toolkit 'uninstall' 'folder-manager'
Check ($r.ok -and -not (Test-Path (Join-Path $pfm 'Project_Folder_Manager.hta'))) 'the Toolkit removes Project Folder Manager'
Check (Test-Path (Join-Path $pfm 'Project_Folder_Manager_config.txt')) 'and keeps its settings file'
$r = Toolkit 'uninstall' 'roadpro'
Check ($r.ok -and -not (Test-Path (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\RoadPro.bundle'))) 'the Toolkit removes RoadPro'
$log = Join-Path $home_ 'toolkit.log'
Check ((Test-Path $log) -and ((Get-Content $log -Raw) -match 'sha256 [0-9a-f]{64}')) 'every job is in toolkit.log'

Step '10. The automatic update, with nobody pressing anything'
# 10. the automatic update, once, as the Toolkit does when it starts and every 4 hours (--auto-update
#     runs the same plan and installer). Slope Calculator is set back to 1.0.2; the feed says Excel to
#     KML and Traverse & Level have newer versions too, with Traverse & Level set to Ask me.
$null = RunAndWait $old @('/S')
StopTools
Check ((Detect 'before-auto').tools.slope.version -eq '1.0.2') 'Slope Calculator 1.0.2 again'
$auto = Get-Content $feed -Raw | ConvertFrom-Json
foreach ($t in $auto.tools) { if ($t.id -in 'excel-to-kml', 'traverse') { $t.version = '99.0.0' } }
$autoFeed = Join-Path $work 'feed-auto.json'
$auto | ConvertTo-Json -Depth 6 | Set-Content -Path $autoFeed -Encoding utf8
$out = Join-Path $work 'result-auto.json'
$code = RunAndWait $exe @('--auto-update', "--feed=$autoFeed", "--result=$out", '--ask=traverse')
$r = Get-Content $out -Raw | ConvertFrom-Json
Write-Host (Get-Content $out -Raw)
Check ($code -eq 0 -and $r.updated.slope -eq $want['slope']) "Slope Calculator is updated to $($want['slope']) by itself"
Check ($r.notification -eq "Slope Calculator updated to $($want['slope'])") "the notification: $($r.notification)"
Check ($r.waiting.'excel-to-kml' -eq 'untilOpened') 'Excel to KML waits until it is opened from the Toolkit'
Check ($r.waiting.traverse -eq 'askMe') 'Traverse & Level, set to Ask me, waits'
Check (-not (Get-Process ExcelToKML, TraverseLevel -ErrorAction SilentlyContinue)) 'nothing opened by itself'
$after = Detect 'after-auto'
Check ($after.tools.slope.version -eq $want['slope'] -and $after.tools.'excel-to-kml'.version -eq $want['excel-to-kml']) 'Slope Calculator updated, Excel to KML left as it was'
Check (-not (Test-Path (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\RoadPro.bundle'))) 'a tool that isn''t installed is never installed by itself'
StopTools

Step '11. Start with Windows and the tray'
# 11. Start with Windows, and the tray
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$out = Join-Path $work 'result-start.json'
$code = RunAndWait $exe @('--start-with-windows=on', "--result=$out")
$value = (Get-ItemProperty -Path $run -Name SurveyToolkit -ErrorAction SilentlyContinue).SurveyToolkit
Write-Host "  Run value: $value"
Check ($code -eq 0 -and $value -eq "`"$exe`" --tray") 'Start with Windows: Windows runs the Toolkit in the tray at sign-in'
$p = Start-Process -FilePath $exe -ArgumentList '--tray' -PassThru
Start-Sleep -Seconds 10
$p.Refresh()
Check (-not $p.HasExited) 'started in the tray, it keeps running'
Check ($p.MainWindowHandle -eq 0) 'with no window, only the tray icon'
Start-Process -FilePath $exe
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -ne 0 } 20) 'opening the Toolkit again shows its window'
Check (@(Get-Process SurveyToolkit -ErrorAction SilentlyContinue).Count -eq 1) 'still one copy'
$null = $p.CloseMainWindow()
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -eq 0 } 20) 'closing the window hides it'
Start-Sleep -Seconds 2
Shot 'tray' 'the desktop after closing the window: the Toolkit in the tray, with its notification' -Plain
$p.Refresh()
Check (-not $p.HasExited) 'and the Toolkit keeps running in the tray'
Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Step '12. Open the Toolkit'
# 12. open the Toolkit
$p = Start-Process -FilePath $exe -PassThru
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -ne 0 -and $p.MainWindowTitle -eq 'Survey Toolkit' } 30) 'opens a window titled "Survey Toolkit"'
Start-Sleep -Seconds 8
Check (-not $p.HasExited) 'still running after 8 seconds'
Shot 'toolkit' 'the Toolkit''s window: the sign-in'
Start-Process -FilePath $exe
Start-Sleep -Seconds 5
Check (@(Get-Process SurveyToolkit -ErrorAction SilentlyContinue).Count -eq 1) 'a second start leaves one copy'

Step '13. The workspace: a web app inside the Toolkit'
# 13. the workspace: Slope Calculator's web app inside the Toolkit's window (Microsoft Edge WebView2)
Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$p = Start-Process -FilePath $exe -ArgumentList '--preview=slope' -PassThru
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -ne 0 -and $p.MainWindowTitle -eq 'Survey Toolkit' } 30) 'the workspace opens'
Check (WaitFor { Test-Path (Join-Path $home_ 'WebView') } 30) 'WebView2 runs, keeping its data in the Toolkit''s folder'
Start-Sleep -Seconds 20 # the web app loads from exceltokml.com
Check (-not $p.HasExited) 'still running with the web app inside'
Shot 'workspace' 'Slope Calculator''s web app inside the Toolkit''s window'

Step '14. The Toolkit updates itself'
# 14. its self-updater downloads the new installer, checks its SHA-256 and runs it with /S /UPDATE
#     while the Toolkit is open; the installer closes it, installs, and opens the new version
Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
$running = Start-Process -FilePath $exe -PassThru
Check (WaitFor { $running.Refresh(); $running.MainWindowHandle -ne 0 } 30) 'the Toolkit is open'
$code = RunAndWait $Installer @('/S', '/UPDATE')
Check ($code -eq 0) 'the new version installs while the Toolkit is open (/S /UPDATE, as its self-updater runs it)'
Check (WaitFor { $running.Refresh(); $running.HasExited } 30) 'the old copy is closed'
Check (WaitFor { $null -ne (Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $running.Id -and $_.MainWindowHandle -ne 0 }) } 30) 'and the new one opens by itself'
Check ($null -ne (Get-ItemProperty -Path $run -Name SurveyToolkit -ErrorAction SilentlyContinue)) 'Start with Windows stays on through the update'
Start-Sleep -Seconds 6
Shot 'after-self-update' 'the Toolkit, open again after updating itself'
Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Step '15. The Toolkit removes the last tools'
# 15. Excel to KML and Traverse & Level (RoadPro, Project Folder Manager and Traverse & Level were
#     removed once already); Slope Calculator stays, to show that uninstalling the Toolkit keeps it
foreach ($id in 'excel-to-kml', 'traverse') {
  $r = Toolkit 'uninstall' $id
  Check $r.ok "the Toolkit uninstalls $id with its own uninstaller"
}
$left = Detect 'after-removing'
Check ($null -eq $left.tools.'excel-to-kml'.version -and $null -eq $left.tools.traverse.version) 'and finds them gone'

Step '16. Uninstall the Toolkit: the tools stay'
# 16. uninstall the Toolkit; the tools stay
$prefs = Join-Path $env:APPDATA 'Excel to KML\Survey Toolkit'
Write-Host "  settings folder before uninstalling: $(if (Test-Path $prefs) { 'there' } else { 'not made' })"
$code = RunAndWait (Join-Path $dir 'Uninstall.exe') @('/S')
Check (WaitFor { -not (Test-Path $dir) } 30) 'uninstall removes the Program folder'
Check (-not (Test-Path $key)) 'uninstall removes it from Settings > Apps'
Check ($null -eq (Get-ItemProperty -Path $run -Name SurveyToolkit -ErrorAction SilentlyContinue)) 'uninstall removes Start with Windows'
Check (-not (Get-Process SurveyToolkit -ErrorAction SilentlyContinue)) 'uninstall closes the Toolkit'
Check (-not (Test-Path (Join-Path $home_ 'WebView'))) 'uninstall removes the web apps'' browser data (their sign-in)'
Check (-not (Test-Path $prefs)) 'uninstall removes the Toolkit''s settings and sign-in'
Check (-not (Test-Path (Join-Path $home_ 'toolkit.log'))) 'uninstall removes the Toolkit''s log'
Check (Test-Path (Join-Path $pfm 'Project_Folder_Manager_config.txt')) 'the tools stay (Project Folder Manager''s settings are still there)'
Check (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SlopeCalculator') 'the tools stay (Slope Calculator is still installed)'

Step '17. Uninstall everything: the PC is clean'
# 17. Slope Calculator with its own uninstaller, as from Settings > Apps; then nothing is left
$apps = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$slope = Get-ItemProperty (Join-Path $apps 'SlopeCalculator')
$null = RunAndWait (Join-Path $slope.InstallLocation 'Uninstall.exe') @('/S')
Check (WaitFor { -not (Test-Path (Join-Path $apps 'SlopeCalculator')) } 60) 'Slope Calculator is removed with its own uninstaller'
foreach ($k in 'ExcelToKMLPro', 'TraversePro', 'SlopeCalculator', 'SurveyToolkit') {
  Check (-not (Test-Path (Join-Path $apps $k))) "nothing in Settings > Apps: no $k"
}
# what each program's own uninstaller leaves is that program's business: noted, not failed
foreach ($t in @(@{ f = 'ExcelToKMLPro'; exe = 'ExcelToKML.exe' }, @{ f = 'TraversePro'; exe = 'TraverseLevel.exe' }, @{ f = 'SlopeCalculator'; exe = 'SlopeCalculator.exe' })) {
  $d = Join-Path $env:LOCALAPPDATA $t.f
  Check (WaitFor { -not (Test-Path (Join-Path $d $t.exe)) } 60) "no $($t.exe) left"
  $files = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($d.Length + 1) })
  if ($files.Count -eq 0) { Check $true "no files left in %LOCALAPPDATA%\$($t.f)" }
  else { Note "$($files.Count) file(s) of the program's own left in %LOCALAPPDATA%\$($t.f) by its uninstaller: $(($files | Select-Object -First 5) -join ', ')" }
}
Check (-not (Test-Path (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\RoadPro.bundle'))) 'no RoadPro in AutoCAD''s plug-ins'
Check (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Survey Toolkit'))) 'no Survey Toolkit in the Start menu'
Check (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Survey Toolkit.lnk'))) 'no Survey Toolkit shortcut on the desktop'
Check ($null -eq (Get-ItemProperty -Path $run -Name SurveyToolkit -ErrorAction SilentlyContinue)) 'nothing starts with Windows'
Check (-not (Get-Process SurveyToolkit, ExcelToKML, TraverseLevel, SlopeCalculator -ErrorAction SilentlyContinue)) 'nothing running'
$kept = @(Get-ChildItem $home_ -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($home_.Length + 1) })
Write-Host "  left in %LOCALAPPDATA%\Survey Toolkit: $($kept -join ', ')"
Check (($kept.Count -eq 1) -and ($kept[0] -eq 'apps\Project Folder Manager\Project_Folder_Manager_config.txt')) 'in %LOCALAPPDATA%\Survey Toolkit only the user''s own Project Folder Manager settings are kept, on purpose'
Shot 'clean' 'the desktop at the end: everything removed' -Plain
Summary "`n**All good.**"
Write-Host 'Survey Toolkit on Windows: all good'
