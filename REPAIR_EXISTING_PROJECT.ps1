$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = 'C:\Users\ANL\Desktop\meta'
$mobile = Join-Path $target 'mobile'
$backend = Join-Path $target 'backend'

if (-not (Test-Path $mobile)) { throw "Bulunamadı: $mobile" }
if (-not (Test-Path $backend)) { throw "Bulunamadı: $backend" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $target "backup-before-advise-repair-$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null

# Backup only the parts we replace.
Copy-Item (Join-Path $mobile 'lib') (Join-Path $backup 'lib') -Recurse -Force
if (Test-Path (Join-Path $mobile 'pubspec.yaml')) { Copy-Item (Join-Path $mobile 'pubspec.yaml') (Join-Path $backup 'pubspec.yaml') -Force }
if (Test-Path (Join-Path $mobile 'assets')) { Copy-Item (Join-Path $mobile 'assets') (Join-Path $backup 'assets') -Recurse -Force }
if (Test-Path (Join-Path $backend 'package.json')) { Copy-Item (Join-Path $backend 'package.json') (Join-Path $backup 'package.json') -Force }

# Replace the broken/stale Dart layer with the checked V13 source.
Remove-Item (Join-Path $mobile 'lib') -Recurse -Force
Copy-Item (Join-Path $root 'mobile\lib') (Join-Path $mobile 'lib') -Recurse -Force
Copy-Item (Join-Path $root 'mobile\assets') (Join-Path $mobile 'assets') -Recurse -Force
Copy-Item (Join-Path $root 'mobile\pubspec.yaml') (Join-Path $mobile 'pubspec.yaml') -Force

# Restore the backend package manifest that is currently missing.
Copy-Item (Join-Path $root 'backend\package.json') (Join-Path $backend 'package.json') -Force

Write-Host ''
Write-Host 'REPAIR TAMAMLANDI.' -ForegroundColor Green
Write-Host "Yedek: $backup"
Write-Host ''
Write-Host 'Siradaki komutlar:'
Write-Host '  cd C:\Users\ANL\Desktop\meta\backend'
Write-Host '  npm.cmd start'
Write-Host ''
Write-Host 'Sonra yeni PowerShell:'
Write-Host '  cd C:\Users\ANL\Desktop\meta\mobile'
Write-Host '  flutter pub get'
Write-Host '  flutter analyze'
Write-Host '  flutter run'
