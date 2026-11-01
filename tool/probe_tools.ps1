# T0 probe: checks on a clean Windows PC (GitHub's Windows runner) everything the Toolkit will
# rely on, using each tool's official public download:
#   the three installers: latest.json, SHA-256, silent install, the installed version in the
#   registry, whether the program opens itself afterwards, what a silent install does to an open
#   copy, and a silent uninstall that leaves nothing behind;
#   the two zips: SHA-256, contents and the version written inside.
# Writes probe/results.json and a table to the run's summary. Exits 1 if a check fails.
#   pwsh tool/probe_tools.ps1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$out = Join-Path (Get-Location) 'probe'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$api = @{ 'User-Agent' = 'survey-toolkit-probe'; 'Accept' = 'application/vnd.github+json' }
if ($env:GITHUB_TOKEN) { $api['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
$uninstallRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'

$programs = @(
  @{ id = 'excel-to-kml'; name = 'Excel to KML'; repo = 'Asjad-Mehmood/kml-convertor'
     installer = 'ExcelToKML-Setup.exe'; key = 'ExcelToKMLPro'; exe = 'ExcelToKML.exe' },
  @{ id = 'traverse'; name = 'Traverse & Level'; repo = 'Asjad-Mehmood/Traiverse'
     installer = 'TraverseLevel-Setup.exe'; key = 'TraversePro'; exe = 'TraverseLevel.exe' },
  @{ id = 'slope'; name = 'Slope Calculator'; repo = 'Asjad-Mehmood/Slope-calculator-'
     installer = 'SlopeCalculator-Setup.exe'; key = 'SlopeCalculator'; exe = 'SlopeCalculator.exe' }
)
$zips = @(
  @{ id = 'roadpro'; name = 'RoadPro'; url = 'https://www.exceltokml.com/roadpro/RoadPro.zip'
     versionFile = 'RoadPro.lsp'; pattern = 'Version\s*:\s*([0-9][0-9.]*)' },
  @{ id = 'folder-manager'; name = 'Project Folder Manager'
     url = 'https://www.exceltokml.com/project-folder-manager/Project_Folder_Manager.zip'
     versionFile = 'Project_Folder_Manager.hta'; pattern = 'PROJECT FOLDER MANAGER\s+v([0-9][0-9.]*)' }
)

$results = @()
$failed = $false

function Sha256([string]$path) { (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLower() }

function ProcName([string]$exe) { [IO.Path]::GetFileNameWithoutExtension($exe) }

function StopProgram([string]$exe) {
  Get-Process -Name (ProcName $exe) -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}

function IsRunning([string]$exe) {
  [bool](Get-Process -Name (ProcName $exe) -ErrorAction SilentlyContinue)
}

function WaitUntil([scriptblock]$test, [int]$seconds) {
  for ($i = 0; $i -lt $seconds; $i++) {
    if (& $test) { return $true }
    Start-Sleep -Seconds 1
  }
  return [bool](& $test)
}

foreach ($p in $programs) {
  $r = [ordered]@{ id = $p.id; name = $p.name; kind = 'installer'; problems = @(); notes = @() }
  Write-Host "`n=== $($p.name)"
  try {
    $rel = Invoke-RestMethod -Headers $api -Uri "https://api.github.com/repos/$($p.repo)/releases/latest"
    $asset = $rel.assets | Where-Object { $_.name -eq $p.installer } | Select-Object -First 1
    if (-not $asset) { throw "the latest release ($($rel.tag_name)) has no $($p.installer)" }
    $r.release = $rel.tag_name
    $r.published = $rel.published_at
    $r.size = $asset.size
    $r.digest = if ($asset.digest) { ($asset.digest -replace '^sha256:', '') } else { $null }

    # latest.json is what installed copies (and the Toolkit) read
    $manifest = $null
    try {
      $manifest = Invoke-RestMethod -Uri "https://github.com/$($p.repo)/releases/latest/download/latest.json"
      $r.latestJson = "version $($manifest.version)"
    } catch {
      $r.latestJson = 'MISSING'
      $r.problems += "latest.json is missing from release $($rel.tag_name): installed copies cannot see this update"
      # a product release problem, not the Toolkit's: a warning on the run, not a failure
      Write-Host "::warning title=$($p.name)::latest.json is missing from release $($rel.tag_name)"
    }
    $want = if ($manifest) { "$($manifest.version)" } else { $rel.tag_name.TrimStart('v') }
    $r.latest = $want

    $file = Join-Path $out $p.installer
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file
    $r.sha256 = Sha256 $file
    if ($manifest -and $manifest.sha256 -ne $r.sha256) { $r.problems += 'SHA-256 differs from latest.json'; $failed = $true }
    if ($r.digest -and $r.digest -ne $r.sha256) { $r.problems += 'SHA-256 differs from the GitHub asset digest'; $failed = $true }

    # 1. silent install on a clean PC
    StopProgram $p.exe
    $run = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
    $r.installExit = $run.ExitCode
    if ($run.ExitCode -ne 0) { $r.problems += "silent install exit code $($run.ExitCode)"; $failed = $true }
    $regPath = Join-Path $uninstallRoot $p.key
    $null = WaitUntil { Test-Path $regPath } 20
    $reg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if (-not $reg) { throw "no uninstall entry at $regPath after a silent install" }
    $r.installedVersion = "$($reg.DisplayVersion)"
    if ($r.installedVersion -ne $want) { $r.problems += "installed version $($r.installedVersion), latest is $want"; $failed = $true }
    $dir = (Get-ItemProperty -Path "HKCU:\Software\$($p.key)" -ErrorAction SilentlyContinue).InstallDir
    if (-not $dir -and $reg.InstallLocation) { $dir = $reg.InstallLocation }
    $r.installDir = $dir
    $r.uninstallString = "$($reg.UninstallString)"
    $r.quietUninstallString = "$($reg.QuietUninstallString)"
    $exePath = Join-Path $dir $p.exe
    if (-not (Test-Path $exePath)) { $r.problems += "$($p.exe) not found in $dir"; $failed = $true }
    $r.opensAfterSilentInstall = WaitUntil { IsRunning $p.exe } 8
    StopProgram $p.exe

    # 2. silent install while the program is open
    $proc = Start-Process -FilePath $exePath -PassThru
    Start-Sleep -Seconds 6
    $proc.Refresh()
    if ($proc.HasExited) {
      $r.openCopy = "the program closed by itself within 6 s (exit $($proc.ExitCode)), so this was not tested"
    } else {
      $run = Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
      $proc.Refresh()
      $r.openCopy = if ($proc.HasExited) { "closed by force (install exit $($run.ExitCode))" } else { "left open (install exit $($run.ExitCode))" }
    }
    StopProgram $p.exe

    # 3. silent uninstall
    $uninstaller = Join-Path $dir 'Uninstall.exe'
    Start-Process -FilePath $uninstaller -ArgumentList '/S' | Out-Null
    $gone = WaitUntil { -not (Test-Path $regPath) -and -not (Test-Path $exePath) } 60
    $r.uninstallClean = $gone
    if (-not $gone) { $r.problems += 'silent uninstall left the registry entry or the program behind'; $failed = $true }
    $r.leftInFolder = if (Test-Path $dir) { @(Get-ChildItem -Path $dir -Recurse -File | ForEach-Object { $_.Name }) } else { @() }
  } catch {
    $r.problems += "error: $($_.Exception.Message)"
    $failed = $true
  }
  StopProgram $p.exe
  $results += [pscustomobject]$r
}

foreach ($z in $zips) {
  $r = [ordered]@{ id = $z.id; name = $z.name; kind = 'zip'; problems = @(); notes = @() }
  Write-Host "`n=== $($z.name)"
  try {
    $file = Join-Path $out ([IO.Path]::GetFileName($z.url))
    Invoke-WebRequest -Uri $z.url -OutFile $file
    $r.size = (Get-Item $file).Length
    $r.sha256 = Sha256 $file
    $dest = Join-Path $out $z.id
    Expand-Archive -Path $file -DestinationPath $dest -Force
    $r.files = @(Get-ChildItem -Path $dest -Recurse -File | ForEach-Object { $_.Name })
    $text = Get-Content -Path (Join-Path $dest $z.versionFile) -Raw
    $m = [regex]::Match($text, $z.pattern)
    if ($m.Success) { $r.latest = $m.Groups[1].Value } else { $r.problems += "no version found in $($z.versionFile)"; $failed = $true }
  } catch {
    $r.problems += "error: $($_.Exception.Message)"
    $failed = $true
  }
  $results += [pscustomobject]$r
}

$results | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $out 'results.json') -Encoding utf8

$md = @('## Survey Toolkit probe', '', '| Tool | Latest | latest.json | Installed | Opens itself after /S | Open copy during /S | Uninstall clean | Problems |', '| --- | --- | --- | --- | --- | --- | --- | --- |')
foreach ($r in $results) {
  $probs = if ($r.problems.Count) { $r.problems -join '; ' } else { 'none' }
  if ($r.kind -eq 'zip') {
    $md += "| $($r.name) | $($r.latest) | (zip, $($r.files.Count) files) | | | | | $probs |"
  } else {
    $md += "| $($r.name) | $($r.latest) ($($r.release)) | $($r.latestJson) | $($r.installedVersion) | $($r.opensAfterSilentInstall) | $($r.openCopy) | $($r.uninstallClean) | $probs |"
  }
}
$md += ''
$md += 'SHA-256:'
foreach ($r in $results) { $md += "- $($r.name): ``$($r.sha256)``" }
$md -join "`n" | Write-Host
if ($env:GITHUB_STEP_SUMMARY) { $md -join "`n" | Add-Content -Path $env:GITHUB_STEP_SUMMARY -Encoding utf8 }

if ($failed) { Write-Host "`nA check failed: see the table and probe/results.json"; exit 1 }
Write-Host "`nEvery check passed"
