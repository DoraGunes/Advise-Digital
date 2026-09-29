# Run PowerShell as Administrator once if a physical phone cannot reach the backend.
$rule = Get-NetFirewallRule -DisplayName 'Advise Digital 3001' -ErrorAction SilentlyContinue
if (-not $rule) {
  New-NetFirewallRule -DisplayName 'Advise Digital 3001' -Direction Inbound -Protocol TCP -LocalPort 3001 -Action Allow -Profile Private | Out-Null
  Write-Host 'Windows Firewall: 3001 acildi.'
} else {
  Write-Host 'Windows Firewall: Advise Digital 3001 kurali zaten mevcut.'
}
