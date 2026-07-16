# Registers `meridian` as a command you can type from anywhere.
# Adds a small function to your PowerShell profile(s) that calls
# scripts\meridian.ps1. Safe to re-run -- it won't duplicate the entry.
# Works for both Windows PowerShell 5.1 and PowerShell 7.

$launcher = 'C:\Users\emmad\Documents\meridian\scripts\meridian.ps1'
$marker   = '# >>> meridian command >>>'
$block = @"
$marker
function meridian { & '$launcher' @args }
# <<< meridian command <<<
"@

# MyDocuments respects OneDrive redirection if present.
$docs = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),  # Windows PowerShell 5.1
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')          # PowerShell 7+
)

foreach ($p in $profiles) {
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $existing = if (Test-Path $p) { Get-Content $p -Raw } else { '' }
    if ($existing -match [regex]::Escape($marker)) {
        Write-Host "  Already registered in $p" -ForegroundColor Gray
    } else {
        Add-Content -Path $p -Value "`r`n$block`r`n"
        Write-Host "  Added meridian command to $p" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Done. Open a NEW terminal and type:  meridian" -ForegroundColor Cyan
