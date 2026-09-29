$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $root 'backend\.env'
if (!(Test-Path $envPath)) { throw "backend\.env bulunamadı: $envPath" }
$secret = Read-Host "Meta App Secret'ı gir"
if ([string]::IsNullOrWhiteSpace($secret)) { throw 'App Secret boş bırakılamaz.' }
$content = Get-Content -LiteralPath $envPath -Raw
if ($content -match '(?m)^META_APP_SECRET=.*$') {
  $content = [regex]::Replace($content, '(?m)^META_APP_SECRET=.*$', "META_APP_SECRET=$secret")
} else {
  $content += "`r`nMETA_APP_SECRET=$secret`r`n"
}
Set-Content -LiteralPath $envPath -Value $content -Encoding UTF8
Write-Host 'META_APP_SECRET backend\\.env içine kaydedildi.' -ForegroundColor Green
