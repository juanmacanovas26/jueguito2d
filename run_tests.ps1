# Runs every validation suite and returns a non-zero exit code if any fails.
#
#   powershell -File run_tests.ps1
#   powershell -File run_tests.ps1 -Verbose      # also print each check
#
# Set GODOT to point at another build if needed.
param([switch]$Verbose)

# Deliberately NOT "Stop": Godot writes to stderr, and PowerShell turns a native
# command's stderr into a terminating error under Stop. The visuals suite even
# emits push_error on purpose (it proves frame-count mismatches are reported),
# so stderr here is expected output, not failure. Suite success is decided by
# the exit code and the reported failure count instead.
$ErrorActionPreference = "Continue"

$godot = $env:GODOT
if (-not $godot) {
    $godot = "C:\Users\Juanma\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
}
if (-not (Test-Path $godot)) {
    Write-Host "Godot not found at: $godot" -ForegroundColor Red
    Write-Host "Set the GODOT environment variable to your Godot console executable."
    exit 2
}

$project = Join-Path $PSScriptRoot "game"
$tmp = Join-Path $env:TEMP "jueguito_tests"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$suites = @(
    @{ Name = "systems";   Scene = "res://tools/validate_systems.tscn";   Frames = 1800 },
    @{ Name = "equipment"; Scene = "res://tools/validate_equipment.tscn"; Frames = 1800 },
    @{ Name = "visuals";   Scene = "res://tools/validate_visuals.tscn";   Frames = 2400 }
)

Write-Host ""
Write-Host "Importing project..." -ForegroundColor DarkGray
& $godot --headless --path $project --import *>&1 | Out-File "$tmp\import.log" -Encoding utf8
$importErrors = (Get-Content "$tmp\import.log" | Select-String "ERROR|Parse Error|Compile Error").Count
if ($importErrors -gt 0) {
    Write-Host "  import reported $importErrors error line(s) - see $tmp\import.log" -ForegroundColor Yellow
}

$failed = 0
$totalChecks = 0
Write-Host ""
foreach ($s in $suites) {
    $log = Join-Path $tmp "$($s.Name).log"
    & $godot --headless --path $project $s.Scene --quit-after $s.Frames *>&1 | Out-File $log -Encoding utf8
    $code = $LASTEXITCODE
    $lines = Get-Content $log
    $summary = ($lines | Select-String "^-- ") -join ""
    if ($summary -match "(\d+) checks, (\d+) failures") {
        $totalChecks += [int]$Matches[1]
        $nfail = [int]$Matches[2]
    } else { $nfail = -1 }

    if ($Verbose) { $lines | Select-String "^\[|^  ok|^  FAIL" | ForEach-Object { "    $_" } }

    if ($code -eq 0 -and $nfail -eq 0) {
        Write-Host ("  PASS  {0,-10} {1}" -f $s.Name, $summary.Trim()) -ForegroundColor Green
    } else {
        $failed++
        Write-Host ("  FAIL  {0,-10} {1}" -f $s.Name, $summary.Trim()) -ForegroundColor Red
        $lines | Select-String "^  FAIL|Parse Error|Compile Error" | ForEach-Object { Write-Host "          $_" -ForegroundColor Red }
        Write-Host "          full log: $log" -ForegroundColor DarkGray
    }
}

# The game itself must boot without errors - a suite can pass while the real
# scene tree is broken.
$bootLog = Join-Path $tmp "boot.log"
& $godot --headless --path $project --quit-after 420 *>&1 | Out-File $bootLog -Encoding utf8
$bootErrors = (Get-Content $bootLog | Select-String "^ERROR|: ERROR:").Count
if ($bootErrors -eq 0) {
    Write-Host ("  PASS  {0,-10} the game boots with 0 errors" -f "boot") -ForegroundColor Green
} else {
    $failed++
    Write-Host ("  FAIL  {0,-10} the game boots with {1} error line(s)" -f "boot", $bootErrors) -ForegroundColor Red
    Write-Host "          full log: $bootLog" -ForegroundColor DarkGray
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "ALL GREEN - $totalChecks checks across $($suites.Count) suites" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed suite(s) failed" -ForegroundColor Red
    exit 1
}
