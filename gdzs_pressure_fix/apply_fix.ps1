param(
    [string]$ProjectPath = "D:\gdzs_calc"
)

$ErrorActionPreference = "Stop"

$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
$SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$Pubspec = Join-Path $ProjectPath "pubspec.yaml"
if (-not (Test-Path $Pubspec)) {
    throw "pubspec.yaml was not found in: $ProjectPath"
}

$TeamTarget = Join-Path $ProjectPath "lib\features\team\new_team_page.dart"
$PressureTarget = Join-Path $ProjectPath "lib\features\team\widgets\pressure_input.dart"

$TeamSource = Join-Path $SourceRoot "new_team_page.dart"
$PressureSource = Join-Path $SourceRoot "pressure_input.dart"

if (-not (Test-Path $TeamSource)) {
    throw "Missing source file: $TeamSource"
}

if (-not (Test-Path $PressureSource)) {
    throw "Missing source file: $PressureSource"
}

New-Item -ItemType Directory -Force -Path (Split-Path $PressureTarget) | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (Test-Path $TeamTarget) {
    Copy-Item $TeamTarget "$TeamTarget.$Timestamp.bak" -Force
}

if (Test-Path $PressureTarget) {
    Copy-Item $PressureTarget "$PressureTarget.$Timestamp.bak" -Force
}

Copy-Item $TeamSource $TeamTarget -Force
Copy-Item $PressureSource $PressureTarget -Force

Write-Host "Files replaced. Backup suffix: .$Timestamp.bak" -ForegroundColor Green

Push-Location $ProjectPath
try {
    Write-Host ""
    Write-Host "Running dart format..." -ForegroundColor Cyan
    & dart format $TeamTarget $PressureTarget
    if ($LASTEXITCODE -ne 0) {
        throw "dart format failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Running flutter analyze..." -ForegroundColor Cyan
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Running flutter test..." -ForegroundColor Cyan
    & flutter test --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Done. Run: flutter run" -ForegroundColor Green
}
finally {
    Pop-Location
}
