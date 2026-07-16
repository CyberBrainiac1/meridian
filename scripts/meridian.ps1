# Meridian one-command demo launcher.
# Boots the Insights dashboard, opens the live skeleton view in the
# browser, and starts the camera + fall-detection Hub -- all at once.
#
# Registered as the `meridian` command (see scripts\install-meridian-command.ps1).
# Usage:
#   meridian                       # laptop webcam
#   meridian --source clip.mp4     # a rehearsed staged-fall clip
#   meridian --loop --source clip.mp4
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $HubArgs
)

$ErrorActionPreference = 'Stop'
$Repo = 'C:\Users\emmad\Documents\meridian'
$Insights = Join-Path $Repo 'meridian_insights'
$Link = 'http://localhost:3000/demo/skeleton'

function Section($msg) { Write-Host ""; Write-Host "  $msg" -ForegroundColor Cyan }

Set-Location $Repo

Write-Host ""
Write-Host "  ███  MERIDIAN — live demo" -ForegroundColor Cyan
Write-Host ""

# --- Pick a python launcher ---------------------------------------------
$py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
      elseif (Get-Command py -ErrorAction SilentlyContinue) { 'py' }
      else { $null }
if (-not $py) { Write-Host "  Python not found on PATH." -ForegroundColor Red; return }

# --- Is the dashboard already up? ---------------------------------------
$dashUp = $false
try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://localhost:3000' | Out-Null; $dashUp = $true } catch {}

if ($dashUp) {
    Section "Dashboard already running."
} else {
    if (-not (Test-Path (Join-Path $Insights 'node_modules'))) {
        Section "First run: installing dashboard (one-time, ~1 min)..."
        Push-Location $Insights; npm install | Out-Null; Pop-Location
    }
    Section "Starting the dashboard..."
    # Own window so it keeps running after this script ends / on Ctrl+C.
    Start-Process -WindowStyle Minimized powershell -ArgumentList @(
        '-NoExit', '-Command', "Set-Location '$Insights'; npm run dev"
    ) | Out-Null

    Write-Host "  Waiting for the dashboard to come up" -NoNewline -ForegroundColor Gray
    for ($i = 0; $i -lt 90; $i++) {
        try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://localhost:3000' | Out-Null; $dashUp = $true; break }
        catch { Write-Host "." -NoNewline -ForegroundColor Gray; Start-Sleep 1 }
    }
    Write-Host ""
}

if (-not $dashUp) {
    Write-Host "  Dashboard didn't come up in time -- check the minimized window for errors." -ForegroundColor Yellow
}

# --- Open the skeleton view ---------------------------------------------
Start-Process $Link | Out-Null

Write-Host ""
Write-Host "  ┌────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "  │  LIVE SKELETON VIEW                                         │" -ForegroundColor Green
Write-Host "  │  $Link              │" -ForegroundColor Green
Write-Host "  │  (opened in your browser — put this on the demo screen)    │" -ForegroundColor Green
Write-Host "  └────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""
Write-Host "  Starting camera + fall detection. Step into view, then stage a fall." -ForegroundColor Cyan
Write-Host "  A red FALL CONFIRMED banner prints here when it fires. Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

# --- Run the Hub in the foreground (Ctrl+C stops it, banners show here) --
$default = @('--source', '0', '--resident', 'Maggie', '--room', 'room-12')
$final = if ($HubArgs -and $HubArgs.Count -gt 0) { $HubArgs } else { $default }
& $py (Join-Path $Repo 'tools\run_live_demo.py') @final
