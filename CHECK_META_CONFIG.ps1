$ErrorActionPreference = "Stop"
$envPath = Join-Path $PSScriptRoot "backend\.env"
if (-not (Test-Path $envPath)) { throw "backend\.env bulunamadı." }
$lines = Get-Content $envPath
$names = @('META_APP_ID','META_LOGIN_CONFIG_ID','META_BUSINESS_ID','META_PAGE_ID','META_INSTAGRAM_USER_ID','META_AD_ACCOUNT_ID','META_REDIRECT_URI')
foreach ($name in $names) {
  $line = $lines | Where-Object { $_ -match "^$name=" } | Select-Object -First 1
  if ($line) { Write-Host $line }
  else { Write-Host "$name=EKSİK" }
}
$secret = $lines | Where-Object { $_ -match '^META_APP_SECRET=' } | Select-Object -First 1
Write-Host (if ($secret -and $secret.Substring(16).Trim()) { 'META_APP_SECRET=AYARLANMIŞ' } else { 'META_APP_SECRET=EKSİK' })
