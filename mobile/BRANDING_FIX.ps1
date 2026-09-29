$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$android = Join-Path $root 'android'
$manifest = Join-Path $android 'app/src/main/AndroidManifest.xml'
$logo = Join-Path $root 'assets/app_icon.png'
$test = Join-Path $root 'test/widget_test.dart'

if (-not (Test-Path $android)) {
  throw "android klasörü bulunamadı. Önce bu klasörde 'flutter create --project-name advise_digital .' çalıştır."
}
if (-not (Test-Path $manifest)) {
  throw "AndroidManifest.xml bulunamadı. Önce: flutter create --project-name advise_digital ."
}
if (-not (Test-Path $logo)) {
  throw "assets/app_icon.png bulunamadı."
}

# App display name.
$manifestText = Get-Content -Raw -Encoding UTF8 $manifest
$manifestText = [regex]::Replace($manifestText, 'android:label="[^"]*"', 'android:label="Advise Digital"', 1)

# Release APK must be allowed to reach the local HTTP backend during development.
if ($manifestText -notmatch 'android:usesCleartextTraffic=') {
  $manifestText = [regex]::Replace($manifestText, '(<application\b)', '$1' + [Environment]::NewLine + '        android:usesCleartextTraffic="true"', 1)
} else {
  $manifestText = [regex]::Replace($manifestText, 'android:usesCleartextTraffic="[^"]*"', 'android:usesCleartextTraffic="true"', 1)
}

# Explicit Internet permission for release builds.
if ($manifestText -notmatch 'android\.permission\.INTERNET') {
  $manifestText = [regex]::Replace($manifestText, '(<manifest\b[^>]*>)', '$1' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.INTERNET" />', 1)
}

# Network Security Config makes local LAN development predictable on Android 9+.
$networkDir = Join-Path $android 'app/src/main/res/xml'
New-Item -ItemType Directory -Force -Path $networkDir | Out-Null
$networkConfig = Join-Path $networkDir 'network_security_config.xml'
@'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
'@ | Set-Content -Path $networkConfig -Encoding UTF8
if ($manifestText -notmatch 'android:networkSecurityConfig=') {
  $manifestText = [regex]::Replace($manifestText, '(android:usesCleartextTraffic="true")', '$1' + [Environment]::NewLine + '        android:networkSecurityConfig="@xml/network_security_config"', 1)
}
Set-Content -Path $manifest -Value $manifestText -Encoding UTF8

# Use the exact supplied Advise Software logo for launcher icons.
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($logo)
try {
  $sizes = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
  }
  foreach ($folder in $sizes.Keys) {
    $dir = Join-Path $android "app/src/main/res/$folder"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($name in @('ic_launcher.png','ic_launcher_round.png')) {
      $n = [int]$sizes[$folder]
      $bmp = New-Object System.Drawing.Bitmap($n, $n)
      try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
          $g.Clear([System.Drawing.Color]::White)
          $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
          $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
          $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
          $g.DrawImage($src, 0, 0, $n, $n)
        } finally { $g.Dispose() }
        $bmp.Save((Join-Path $dir $name), [System.Drawing.Imaging.ImageFormat]::Png)
      } finally { $bmp.Dispose() }
    }
  }
} finally { $src.Dispose() }

$adaptive = Join-Path $android 'app/src/main/res/mipmap-anydpi-v26'
if (Test-Path $adaptive) {
  Remove-Item (Join-Path $adaptive 'ic_launcher.xml') -Force -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $adaptive 'ic_launcher_round.xml') -Force -ErrorAction SilentlyContinue
}

# Recreate the project-independent smoke test if flutter create replaced it.
if (Test-Path (Split-Path $test -Parent)) {
  @'
import 'package:flutter_test/flutter_test.dart';
import 'package:advise_digital/main.dart';

void main() {
  testWidgets('Advise Digital login ekranı açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const AdviseDigitalApp());
    await tester.pump();
    expect(find.text('ADVISE DIGITAL'), findsOneWidget);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });
}
'@ | Set-Content -Path $test -Encoding UTF8
}

Write-Host 'Tamam: Advise Digital markalama, launcher logo, Internet/HTTP ve smoke test hazır.'
