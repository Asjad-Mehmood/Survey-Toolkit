# T2 on a clean Windows PC (GitHub's Windows machines, no graphics card):
#   1. install the Toolkit silently and check its files, shortcuts and Settings > Apps entry;
#   2. on a PC with none of the tools, the Toolkit finds none of them;
#   3. install the real tools from their official downloads: the three installers silently, and
#      RoadPro and Project Folder Manager where the Toolkit will put them (T3);
#   4. the Toolkit finds every one, with the right version and the program to open;
#   5. open the Toolkit: a drawn window with the sign-in, a screenshot, one copy on a second start;
#   6. uninstall the Toolkit: its folder and entry go, the tools stay.
#   pwsh tool/windows_check.ps1 installer\SurveyToolkit-Setup.exe windows-check.png
param([Parameter(Mandatory)] [string] $Installer, [string] $Screenshot = 'windows-check.png')
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

function Check($ok, $what) { if (-not $ok) { throw "FAILED: $what" } else { Write-Host "ok  $what" } }
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
function Detect([string] $name) {
  $out = Join-Path $work "$name.json"
  Remove-Item $out -ErrorAction SilentlyContinue
  $code = RunAndWait $exe @("--detect=$out")
  Check ($code -eq 0 -and (Test-Path $out)) "--detect ($name) ran and wrote its result"
  $j = Get-Content $out -Raw | ConvertFrom-Json
  Write-Host (Get-Content $out -Raw)
  return $j
}

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

# 2. a PC with none of the tools
$none = Detect 'none'
foreach ($id in 'excel-to-kml', 'roadpro', 'traverse', 'folder-manager', 'slope') {
  Check ($null -eq $none.tools.$id.version) "finds no $id on a clean PC"
}

# 3. the real tools, from their official downloads
$want = @{}
$programs = @(
  @{ id = 'excel-to-kml'; repo = 'Asjad-Mehmood/kml-convertor'; file = 'ExcelToKML-Setup.exe'; exe = 'ExcelToKML' },
  @{ id = 'traverse'; repo = 'Asjad-Mehmood/Traiverse'; file = 'TraverseLevel-Setup.exe'; exe = 'TraverseLevel' },
  @{ id = 'slope'; repo = 'Asjad-Mehmood/Slope-calculator-'; file = 'SlopeCalculator-Setup.exe'; exe = 'SlopeCalculator' }
)
foreach ($p in $programs) {
  $rel = Invoke-RestMethod -Headers $api -Uri "https://api.github.com/repos/$($p.repo)/releases/latest"
  $asset = $rel.assets | Where-Object { $_.name -eq $p.file } | Select-Object -First 1
  $f = Join-Path $work $p.file
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $f
  $code = RunAndWait $f @('/S')
  Check ($code -eq 0) "installed $($p.file) $($rel.tag_name)"
  $want[$p.id] = $rel.tag_name.TrimStart('v')
  Start-Sleep -Seconds 3
  Get-Process -Name $p.exe -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$bundle = Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\RoadPro.bundle\Contents'
$zip = Join-Path $work 'RoadPro.zip'
Invoke-WebRequest -Uri 'https://www.exceltokml.com/roadpro/RoadPro.zip' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $bundle -Force
$want['roadpro'] = [regex]::Match((Get-Content (Join-Path $bundle 'RoadPro.lsp') -Raw), 'Version\s*:\s*([0-9.]+)').Groups[1].Value

$pfm = Join-Path $home_ 'apps\Project Folder Manager'
$zip = Join-Path $work 'Project_Folder_Manager.zip'
Invoke-WebRequest -Uri 'https://www.exceltokml.com/project-folder-manager/Project_Folder_Manager.zip' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $pfm -Force
$want['folder-manager'] = [regex]::Match((Get-Content (Join-Path $pfm 'Project_Folder_Manager.hta') -Raw), 'PROJECT FOLDER MANAGER\s+v([0-9.]+)').Groups[1].Value

# 4. the Toolkit finds them all
$all = Detect 'all'
foreach ($id in $want.Keys) {
  Check ($all.tools.$id.version -eq $want[$id]) "finds $id $($want[$id]) (found: $($all.tools.$id.version))"
}
foreach ($id in 'excel-to-kml', 'traverse', 'slope', 'folder-manager') {
  Check ($all.tools.$id.program -and (Test-Path $all.tools.$id.program)) "knows the program to open for $id"
}
Check ($all.tools.roadpro.note -eq 'AutoCAD not found on this PC') 'says AutoCAD is not on this PC (RoadPro needs it)'

# 5. open the Toolkit
$p = Start-Process -FilePath $exe -PassThru
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -ne 0 -and $p.MainWindowTitle -eq 'Survey Toolkit' } 30) 'opens a window titled "Survey Toolkit"'
Start-Sleep -Seconds 8
Check (-not $p.HasExited) 'still running after 8 seconds'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
[System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
$bmp.Save($Screenshot, [System.Drawing.Imaging.ImageFormat]::Png)
$colours = @{}
for ($x = 0; $x -lt $screen.Width; $x += 23) { for ($y = 0; $y -lt $screen.Height; $y += 19) { $colours[$bmp.GetPixel($x, $y).ToArgb()] = 1 } }
Write-Host "screenshot: $Screenshot ($($screen.Width)x$($screen.Height), $($colours.Count) colours)"
Check ($colours.Count -gt 20) 'the screen shows a drawn window, not a blank one'
Start-Process -FilePath $exe
Start-Sleep -Seconds 5
Check (@(Get-Process SurveyToolkit -ErrorAction SilentlyContinue).Count -eq 1) 'a second start leaves one copy'

# 6. uninstall the Toolkit; the tools stay
$code = RunAndWait (Join-Path $dir 'Uninstall.exe') @('/S')
Check (WaitFor { -not (Test-Path $dir) } 30) 'uninstall removes the Program folder'
Check (-not (Test-Path $key)) 'uninstall removes it from Settings > Apps'
Check (-not (Get-Process SurveyToolkit -ErrorAction SilentlyContinue)) 'uninstall closes the Toolkit'
Check (Test-Path (Join-Path $pfm 'Project_Folder_Manager.hta')) 'the tools stay (Project Folder Manager is still there)'
Check (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SlopeCalculator') 'the tools stay (Slope Calculator is still installed)'
Write-Host 'Survey Toolkit on Windows: all good'
