# Scrolling in the real Toolkit window (Windows, WebView2 drawn off-screen).
#
# 1. A test page laid out like the Flutter web apps (tool/scroll_test): a fixed header, and under it
#    the panel that scrolls. The mouse wheel is turned by Windows itself (SetCursorPos, mouse_event)
#    over the middle of the panel; the page reports where the wheel arrived and whether it scrolled.
# 2. The real Slope Calculator web app (--preview=slope): screenshots before and after the wheel,
#    and whether the page moved.
#   pwsh tool/scroll_check.ps1 [build\windows\x64\runner\Release\SurveyToolkit.exe] [shots-scroll]
param([string] $Exe = 'build\windows\x64\runner\Release\SurveyToolkit.exe', [string] $Shots = 'shots-scroll')
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Shots | Out-Null
$log = Join-Path (Get-Location) 'scroll-log.txt'
Remove-Item $log -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, int d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
}
"@
$script:fails = 0
function Summary([string] $line) { Write-Host $line; if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $line -Encoding utf8 } }
function Result([bool] $ok, [string] $what) { if ($ok) { Summary "- :white_check_mark: $what" } else { $script:fails++; Summary "- :x: **$what**" } }
$script:n = 0
function Grab { $s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $b = New-Object System.Drawing.Bitmap $s.Width, $s.Height; [System.Drawing.Graphics]::FromImage($b).CopyFromScreen($s.Location, [System.Drawing.Point]::Empty, $s.Size); return $b }
function Shot([string] $name, $bmp) { $script:n++; $f = Join-Path $Shots ('{0:D2}-{1}.png' -f $script:n, $name); $bmp.Save($f, [System.Drawing.Imaging.ImageFormat]::Png); Summary "- :camera: ``$(Split-Path $f -Leaf)``" }
function Lines { if (Test-Path $log) { @(Get-Content $log) } else { @() } }
function WaitLine([string] $pattern, [int] $seconds) {
  for ($i = 0; $i -lt $seconds * 4; $i++) { $m = Lines | Where-Object { $_ -match $pattern } | Select-Object -Last 1; if ($m) { return $m }; Start-Sleep -Milliseconds 250 }
  return $null
}
function Open([string] $arg) {
  Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep -Seconds 2
  $p = Start-Process -FilePath $Exe -ArgumentList $arg -PassThru
  for ($i = 0; $i -lt 60 -and $p.MainWindowHandle -eq 0; $i++) { Start-Sleep -Milliseconds 500; $p.Refresh() }
  [void][W]::ShowWindow($p.MainWindowHandle, 3); Start-Sleep -Milliseconds 500
  [void][W]::SetForegroundWindow($p.MainWindowHandle)
  return $p
}
# a point in the window's client area, as a share of its width and height, on the screen
function At($p, [double] $fx, [double] $fy) {
  $r = New-Object W+RECT; [void][W]::GetClientRect($p.MainWindowHandle, [ref]$r)
  $pt = New-Object W+POINT; [void][W]::ClientToScreen($p.MainWindowHandle, [ref]$pt)
  return @([int]($pt.X + ($r.R - $r.L) * $fx), [int]($pt.Y + ($r.B - $r.T) * $fy))
}
# the mouse moved there as a person would (two moves, so it hovers), then the wheel turned down
function Wheel([int] $x, [int] $y, [int] $notches) {
  [void][W]::SetCursorPos($x, $y); Start-Sleep -Milliseconds 300
  [void][W]::SetCursorPos($x + 2, $y + 1); Start-Sleep -Milliseconds 300
  for ($i = 0; $i -lt $notches; $i++) { [W]::mouse_event(0x0800, 0, 0, -120, [IntPtr]::Zero); Start-Sleep -Milliseconds 150 }
  Start-Sleep -Seconds 2
}
# how much of a screen area changed between two screenshots (share of sampled pixels)
function Changed($a, $b, [int] $x0, [int] $y0, [int] $x1, [int] $y1) {
  $diff = 0; $all = 0
  for ($y = $y0; $y -lt $y1; $y += 6) { for ($x = $x0; $x -lt $x1; $x += 6) { $all++; if ($a.GetPixel($x, $y).ToArgb() -ne $b.GetPixel($x, $y).ToArgb()) { $diff++ } } }
  if ($all -eq 0) { return 0 } else { return [math]::Round($diff / $all, 3) }
}

Summary '## Scrolling in the real Toolkit window'

# ---------- 1. the test page ----------
Summary '### A page laid out like the Flutter web apps'
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
$srv = Start-Process -FilePath $py -ArgumentList @('tool/scroll_test/server.py', '8124', "`"$log`"") -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$p = Open '--preview-url=http://localhost:8124/index.html'
$loaded = WaitLine '^loaded' 60
Start-Sleep -Seconds 2
Result ($null -ne $loaded) "the test page loads in the Toolkit window ($loaded)"
if ($loaded) {
  $before = Grab; Shot 'page-before' $before
  # over the middle of the panel, over its top, and over the header
  foreach ($spot in @(@(0.6, 0.65, 'the middle of the panel'), @(0.5, 0.33, 'the top of the panel'), @(0.5, 0.18, 'the header'))) {
    $xy = At $p $spot[0] $spot[1]
    $from = (Lines).Count
    Wheel $xy[0] $xy[1] 3
    $got = (Lines) | Select-Object -Skip $from
    Summary "- wheel over $($spot[2]) (screen $($xy[0]),$($xy[1])): $(if ($got) { $got -join ' | ' } else { 'nothing reached the page' })"
  }
  $after = Grab; Shot 'page-after' $after
  $scrolled = WaitLine '^panel scrolled to [1-9]' 5
  Result ($null -ne $scrolled) "the panel under the mouse scrolls$(if ($scrolled) { " ($scrolled)" })"
}
$srv | Stop-Process -Force -ErrorAction SilentlyContinue

# ---------- 2. the real Slope Calculator ----------
Summary '### Slope Calculator''s web app'
$p = Open '--preview=slope'
Start-Sleep -Seconds 25 # the web app loads from exceltokml.com
$xy = At $p 0.6 0.65
# the page area: right of the sidebar, under the app bar
$tl = At $p 0.15 0.2; $br = At $p 0.97 0.95
$before = Grab; Shot 'slope-before' $before
Wheel $xy[0] $xy[1] 5
$after = Grab; Shot 'slope-after' $after
$share = Changed $before $after $tl[0] $tl[1] $br[0] $br[1]
Result ($share -gt 0.05) "the Slope Calculator's page moves when the wheel is turned over it ($([math]::Round($share * 100, 1)) % of the page changed)"
Get-Process SurveyToolkit -ErrorAction SilentlyContinue | Stop-Process -Force

Summary "`n``````"
(Lines) | ForEach-Object { Summary $_ }
Summary '```'
if ($script:fails) { throw "$($script:fails) scrolling check(s) failed" }
