# Drop-down lists in the real Toolkit window (Windows, WebView2 drawn off-screen).
#
# Opens a test page in the Toolkit's window (--preview-url): a drop-down on the page itself and one
# in a frame, as the website shows Excel to KML. The mouse is moved and clicked by Windows itself
# (SetCursorPos, mouse_event), like a person: on each drop-down, then on its third item. The pages
# send what happens to a little local server (tool/selects_test): which fixes run there, each press,
# the list when it opens, each choice. All of it goes on the run's summary page, with screenshots.
#   pwsh tool/selects_check.ps1 [build\windows\x64\runner\Release\SurveyToolkit.exe] [shots-selects]
param([string] $Exe = 'build\windows\x64\runner\Release\SurveyToolkit.exe', [string] $Shots = 'shots-selects')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Shots | Out-Null
$log = Join-Path (Get-Location) 'selects-log.txt'
Remove-Item $log -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class U {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
}
"@
function Summary([string] $line) { Write-Host $line; if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $line -Encoding utf8 } }
$script:n = 0
function Shot([string] $name) {
  $script:n++
  $file = Join-Path $Shots ('{0:D2}-{1}.png' -f $script:n, $name)
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
  [System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  Summary "- :camera: ``$(Split-Path $file -Leaf)``"
}
function Lines { if (Test-Path $log) { @(Get-Content $log) } else { @() } }
function WaitLine([string] $pattern, [int] $seconds) {
  for ($i = 0; $i -lt $seconds * 4; $i++) { $m = Lines | Where-Object { $_ -match $pattern } | Select-Object -Last 1; if ($m) { return $m }; Start-Sleep -Milliseconds 250 }
  return $null
}
function Click([int] $x, [int] $y) {
  [void][U]::SetCursorPos($x, $y); Start-Sleep -Milliseconds 300
  [void][U]::SetCursorPos($x + 1, $y); Start-Sleep -Milliseconds 200
  [U]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 120
  [U]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 1500
}

Summary '## Drop-down lists in the real Toolkit window'
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
$srv = Start-Process -FilePath $py -ArgumentList @('tool/selects_test/server.py', '8123', "`"$log`"") -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$p = Start-Process -FilePath $Exe -ArgumentList '--preview-url=http://localhost:8123/top.html' -PassThru
for ($i = 0; $i -lt 60 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 500; $p.Refresh() }
[void][U]::ShowWindow($p.MainWindowHandle, 3)
[void][U]::SetForegroundWindow($p.MainWindowHandle)
$frameLoaded = WaitLine '^frame: loaded' 60
Start-Sleep -Seconds 2
Shot 'loaded'
Summary "- page reports: $((Lines | Where-Object { $_ -match 'loaded' }) -join ' | ')"
if (-not $frameLoaded) { Summary '- :x: the test page did not load in the Toolkit window'; $p | Stop-Process -Force; $srv | Stop-Process -Force; exit 0 }

$pt = New-Object U+POINT
[void][U]::ClientToScreen($p.MainWindowHandle, [ref]$pt)
$scale = [U]::GetDpiForWindow($p.MainWindowHandle) / 96.0
# the preview: the sidebar (92) and its line, then the app bar (56) and its line, then the page
$ox = $pt.X + [int](93 * $scale); $oy = $pt.Y + [int](57 * $scale)
Summary "- window client at $($pt.X),$($pt.Y); scale $scale; page at $ox,$oy"

foreach ($where in 'top', 'frame') {
  $sel = WaitLine "^${where}: select at" 5
  if (-not ($sel -match 'at (\d+),(\d+)')) { Summary "- :x: $where no select position"; continue }
  $fx = [int]$Matches[1]; $fy = [int]$Matches[2]
  if ($where -eq 'frame') { $fy += 204 }
  $before = (Lines).Count
  Click ($ox + [int]($fx * $scale)) ($oy + [int]($fy * $scale))
  Shot "$where-pressed"
  $new = (Lines) | Select-Object -Skip $before
  Summary "- $where, after pressing the drop-down: $($new -join ' | ')"
  $open = $new | Where-Object { $_ -match "^${where}: list open.*item 3 at (\d+),(\d+)" } | Select-Object -Last 1
  if ($open -and $open -match 'item 3 at (\d+),(\d+)') {
    $ix = [int]$Matches[1]; $iy = [int]$Matches[2]
    if ($where -eq 'frame') { $iy += 204 }
    $before = (Lines).Count
    Click ($ox + [int]($ix * $scale)) ($oy + [int]($iy * $scale))
    Shot "$where-picked"
    $new = (Lines) | Select-Object -Skip $before
    $picked = $new | Where-Object { $_ -match "^${where}: picked" }
    if ($picked) { Summary "- :white_check_mark: **$where`: $picked**" } else { Summary "- :x: **$where`: the list opened but picking did nothing** ($($new -join ' | '))" }
  } else {
    Summary "- :x: **$where`: no in-page list opened**"
  }
}
Summary "`n``````"
(Lines) | ForEach-Object { Summary $_ }
Summary '```'
$p | Stop-Process -Force -ErrorAction SilentlyContinue
$srv | Stop-Process -Force -ErrorAction SilentlyContinue
