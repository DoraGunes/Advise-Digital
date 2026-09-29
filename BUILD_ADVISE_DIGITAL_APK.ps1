$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobile = Join-Path $root 'mobile'
Set-Location $mobile

Write-Host '1/5 Flutter Android proje dosyalari yenileniyor...'
flutter create --project-name advise_digital .
Write-Host '2/5 Markalama, Internet/HTTP ve test sabitleniyor...'
powershell -ExecutionPolicy Bypass -File .\BRANDING_FIX.ps1
Write-Host '3/5 Paketler aliniyor...'
flutter pub get
Write-Host '4/5 Analiz + test...'
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze hata verdi.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test hata verdi.' }
Write-Host '5/5 Release APK olusturuluyor...'
flutter build apk --release
Write-Host ''
Write-Host 'APK hazir:'
Write-Host (Join-Path $mobile 'build\app\outputs\flutter-apk\app-release.apk')
