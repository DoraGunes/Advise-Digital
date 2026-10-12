# Read-only diagnosis. Never prints tokens, raw errors, captions, URLs or .env contents.
param(
  [Parameter(Mandatory=$true)][string]$BackendPath,
  [string]$DataPath=''
)
$ErrorActionPreference='Stop'
function SafeCode($Value) {
  $text=("$Value").Trim().ToUpperInvariant()
  if($text -cmatch '^[A-Z_]{3,60}{return $text}
  return 'UNKNOWN'
}
function SafeNumber($Value) {
  if("$Value" -match '^\d{1,12}(\.\d{1,2})?$'){return "$Value"}
  return 'NONE'
}
function ErrorCategory($Value) {
  $text="$Value"
  if($text -match 'HTTPS'){return 'HTTPS_REQUIRED'}
  if($text -match 'token|kullanıcı ID'){return 'CREDENTIALS'}
  if($text -match 'timeout|zaman aşım'){return 'TIMEOUT'}
  if($text -match 'Instagram API'){return 'IG_PROVIDER'}
  if($text){return 'OTHER'}
  return 'NONE'
}
function ProviderHttp($Value) {
  if("$Value" -match 'Instagram API (\d{3})'){return $Matches[1]}
  return 'NONE'
}
function ProviderCode($Value) {
  if("$Value" -match '(?:\(|,\s*)kod (\d{1,8})'){return $Matches[1]}
  return 'NONE'
}
function ProviderSubcode($Value) {
  if("$Value" -match 'alt kod (\d{1,12})'){return $Matches[1]}
  return 'NONE'
}
$d=Join-Path $BackendPath 'data'
if($DataPath){$d=$DataPath}
else {
  $envFile=Join-Path $BackendPath '.env'
  if(Test-Path $envFile) {
    $line=Get-Content $envFile | Where-Object {$_ -match '^\s*ADVISE_DATA_DIR\s*='} | Select-Object -Last 1
    if($line) {
      $value=($line -split '=',2)[1].Trim()
      # Strip dotenv comments outside quoted paths, without exposing any setting.
      if($value.StartsWith('"') -or $value.StartsWith("'")){
        $quote=$value.Substring(0,1)
        $end=$value.IndexOf($quote,1)
        if($end -gt 0){$value=$value.Substring(1,$end-1)}
      }else{$value=($value -split '\s+#',2)[0].Trim()}
      if($value){$d=if([IO.Path]::IsPathRooted($value)){$value}else{Join-Path $BackendPath $value}}
    }
  }
  if($env:ADVISE_DATA_DIR){$d=$env:ADVISE_DATA_DIR}
}
try {
  $health=Invoke-RestMethod 'http://127.0.0.1:3001/health' -TimeoutSec 5
  $marker=if("$($health.buildMarker)" -cmatch '^[A-Z0-9_]{1,80}$'){"$($health.buildMarker)"}else{'UNKNOWN'}
  'API_OK='+($health.ok -eq $true)+' API_VERSION='+(SafeNumber $health.apiVersion)+' AD_SAGA='+($health.capabilities.adCreateSaga -eq $true)+' MARKER='+$marker
}catch{'API_UNAVAILABLE'}
try {
  $server=Get-Content -Raw -Encoding UTF8 (Join-Path $BackendPath 'src\server.js')
  $safety=Get-Content -Raw -Encoding UTF8 (Join-Path $BackendPath 'src\automation-safety.js')
  $pattern='tenantId\s*===\s*[''"]system[''"]\s*\?'
  'SERVER_SYSTEM_ENV_BYPASS='+([bool]($server -match $pattern))+' HELPER_SYSTEM_ENV_BYPASS='+([bool]($safety -match $pattern))
}catch{'SOURCE_CHECK_UNAVAILABLE'}
foreach($name in @('ad_operations','posts','logs','tenants','settings')){
  $file=Join-Path $d ($name+'.json')
  if(!(Test-Path $file)){($name+': MISSING');continue}
  try {
    $raw=Get-Content -Raw -Encoding UTF8 $file | ConvertFrom-Json
    $rows=@($raw | Where-Object {$null -ne $_})
    if($name -eq 'settings'){
      $settings=if($raw.PSObject.Properties.Name -contains 'system'){$raw.system}else{$raw}
      'SYSTEM_BUDGET_CAP='+(SafeNumber $settings.geminiAdsDailyCap)+' MAX_DAILY='+(SafeNumber $settings.maxDailyBudget)
      continue
    }
    ($name+': COUNT='+$rows.Count)
    if($name -eq 'ad_operations'){
      $rows | Sort-Object updatedAt -Descending | Select-Object -First 5 | ForEach-Object {
        'AD system='+($_.tenantId -eq 'system')+' status='+(SafeCode $_.status)+' stage='+(SafeCode $_.failure.stage)+' code='+(SafeCode $_.failure.code)+' provider='+(SafeNumber $_.providerFailure.code)+' subcode='+(SafeNumber $_.providerFailure.subcode)+' http='+(SafeNumber $_.providerFailure.status)
      }
    }
    if($name -eq 'posts'){
      $rows | Group-Object publishStatus | ForEach-Object {'QUEUE status='+(SafeCode $_.Name)+' count='+$_.Count}
      $rows | Sort-Object createdAt -Descending | Select-Object -First 5 | ForEach-Object {
        $exists=$false
        if($_.filePath){$exists=Test-Path $_.filePath}
        'POST system='+($_.tenantId -eq 'system' -or !$_.tenantId)+' type='+(SafeCode $_.mediaType)+' status='+(SafeCode $_.publishStatus)+' phase='+(SafeCode $_.publishPhase)+' ai='+(SafeCode $_.aiStatus)+' auto='+($_.autoPublish -eq $true)+' fileExists='+$exists+' https='+("$($_.publicUrl)" -match '^https://')+' scheduled='+([bool]$_.nextPublishAt)+' errorCategory='+(ErrorCategory $_.publishError)+' igHttp='+(ProviderHttp $_.publishError)+' igCode='+(ProviderCode $_.publishError)+' igSubcode='+(ProviderSubcode $_.publishError)+' savedFailure='+(SafeCode $_.publishFailure.code)+' savedProvider='+(SafeNumber $_.publishFailure.providerFailure.code)+' savedSubcode='+(SafeNumber $_.publishFailure.providerFailure.subcode)+' savedHttp='+(SafeNumber $_.publishFailure.providerFailure.status)
      }
    }
    if($name -eq 'logs'){
      $rows | Where-Object {$_.type -in @('INSTAGRAM_POST_ERROR','INSTAGRAM_POST_PUBLISHED','POST_UPLOADED','POST_QUEUED','WEEKLY_LAUNCH_ERROR')} | Sort-Object at -Descending | Select-Object -First 10 | ForEach-Object {
        'LOG type='+(SafeCode $_.type)+' stage='+(SafeCode $_.stage)+' status='+(SafeCode $_.status)+' attempt='+(SafeNumber $_.attempt)+' errorCategory='+(ErrorCategory $_.error)+' igHttp='+(ProviderHttp $_.error)+' igCode='+(ProviderCode $_.error)+' igSubcode='+(ProviderSubcode $_.error)
      }
    }
    if($name -eq 'tenants'){
      $rows | Where-Object {$_.id -eq 'system' -or $_.meta.connected -eq $true} | ForEach-Object {
        'CONNECTION system='+($_.id -eq 'system')+' connected='+($_.meta.connected -eq $true)+' source='+(SafeCode $_.meta.source)+' api='+(SafeCode $_.meta.instagramApi)+' metaTokenPresent='+([bool]($_.meta.accessToken -or $_.meta.metaAccessToken))+' igTokenPresent='+([bool]$_.meta.instagramAccessToken)+' pagePresent='+([bool]$_.meta.pageId)+' igIdPresent='+([bool]$_.meta.instagramUserId)+' adAccountPresent='+([bool]$_.meta.adAccountId)
      }
    }
  }catch{($name+': READ_ERROR')}
}
'READ_ONLY_DONE'
){return $text}
  return 'UNKNOWN'
}
function SafeNumber($Value) {
  if("$Value" -match '^\d{1,12}(\.\d{1,2})?$'){return "$Value"}
  return 'NONE'
}
function ErrorCategory($Value) {
  $text="$Value"
  if($text -match 'HTTPS'){return 'HTTPS_REQUIRED'}
  if($text -match 'token|kullanıcı ID'){return 'CREDENTIALS'}
  if($text -match 'timeout|zaman aşım'){return 'TIMEOUT'}
  if($text -match 'Instagram API'){return 'IG_PROVIDER'}
  if($text){return 'OTHER'}
  return 'NONE'
}
function ProviderHttp($Value) {
  if("$Value" -match 'Instagram API (\d{3})'){return $Matches[1]}
  return 'NONE'
}
function ProviderCode($Value) {
  if("$Value" -match '(?:\(|,\s*)kod (\d{1,8})'){return $Matches[1]}
  return 'NONE'
}
function ProviderSubcode($Value) {
  if("$Value" -match 'alt kod (\d{1,12})'){return $Matches[1]}
  return 'NONE'
}
$d=Join-Path $BackendPath 'data'
if($DataPath){$d=$DataPath}
else {
  $envFile=Join-Path $BackendPath '.env'
  if(Test-Path $envFile) {
    $line=Get-Content $envFile | Where-Object {$_ -match '^\s*ADVISE_DATA_DIR\s*='} | Select-Object -Last 1
    if($line) {
      $value=($line -split '=',2)[1].Trim()
      # Strip dotenv comments outside quoted paths, without exposing any setting.
      if($value.StartsWith('"') -or $value.StartsWith("'")){
        $quote=$value.Substring(0,1)
        $end=$value.IndexOf($quote,1)
        if($end -gt 0){$value=$value.Substring(1,$end-1)}
      }else{$value=($value -split '\s+#',2)[0].Trim()}
      if($value){$d=if([IO.Path]::IsPathRooted($value)){$value}else{Join-Path $BackendPath $value}}
    }
  }
  if($env:ADVISE_DATA_DIR){$d=$env:ADVISE_DATA_DIR}
}
try {
  $health=Invoke-RestMethod 'http://127.0.0.1:3001/health' -TimeoutSec 5
  $marker=if("$($health.buildMarker)" -match '^[A-Z0-9_]{1,80}$'){"$($health.buildMarker)"}else{'UNKNOWN'}
  'API_OK='+($health.ok -eq $true)+' API_VERSION='+(SafeNumber $health.apiVersion)+' AD_SAGA='+($health.capabilities.adCreateSaga -eq $true)+' MARKER='+$marker
}catch{'API_UNAVAILABLE'}
try {
  $server=Get-Content -Raw -Encoding UTF8 (Join-Path $BackendPath 'src\server.js')
  $safety=Get-Content -Raw -Encoding UTF8 (Join-Path $BackendPath 'src\automation-safety.js')
  $pattern='tenantId\s*===\s*[''"]system[''"]\s*\?'
  'SERVER_SYSTEM_ENV_BYPASS='+([bool]($server -match $pattern))+' HELPER_SYSTEM_ENV_BYPASS='+([bool]($safety -match $pattern))
}catch{'SOURCE_CHECK_UNAVAILABLE'}
foreach($name in @('ad_operations','posts','logs','tenants','settings')){
  $file=Join-Path $d ($name+'.json')
  if(!(Test-Path $file)){($name+': MISSING');continue}
  try {
    $raw=Get-Content -Raw -Encoding UTF8 $file | ConvertFrom-Json
    $rows=@($raw | Where-Object {$null -ne $_})
    if($name -eq 'settings'){
      $settings=if($raw.PSObject.Properties.Name -contains 'system'){$raw.system}else{$raw}
      'SYSTEM_BUDGET_CAP='+(SafeNumber $settings.geminiAdsDailyCap)+' MAX_DAILY='+(SafeNumber $settings.maxDailyBudget)
      continue
    }
    ($name+': COUNT='+$rows.Count)
    if($name -eq 'ad_operations'){
      $rows | Sort-Object updatedAt -Descending | Select-Object -First 5 | ForEach-Object {
        'AD system='+($_.tenantId -eq 'system')+' status='+(SafeCode $_.status)+' stage='+(SafeCode $_.failure.stage)+' code='+(SafeCode $_.failure.code)+' provider='+(SafeNumber $_.providerFailure.code)+' subcode='+(SafeNumber $_.providerFailure.subcode)+' http='+(SafeNumber $_.providerFailure.status)
      }
    }
    if($name -eq 'posts'){
      $rows | Group-Object publishStatus | ForEach-Object {'QUEUE status='+(SafeCode $_.Name)+' count='+$_.Count}
      $rows | Sort-Object createdAt -Descending | Select-Object -First 5 | ForEach-Object {
        $exists=$false
        if($_.filePath){$exists=Test-Path $_.filePath}
        'POST system='+($_.tenantId -eq 'system' -or !$_.tenantId)+' type='+(SafeCode $_.mediaType)+' status='+(SafeCode $_.publishStatus)+' phase='+(SafeCode $_.publishPhase)+' ai='+(SafeCode $_.aiStatus)+' auto='+($_.autoPublish -eq $true)+' fileExists='+$exists+' https='+("$($_.publicUrl)" -match '^https://')+' scheduled='+([bool]$_.nextPublishAt)+' errorCategory='+(ErrorCategory $_.publishError)+' igHttp='+(ProviderHttp $_.publishError)+' igCode='+(ProviderCode $_.publishError)+' igSubcode='+(ProviderSubcode $_.publishError)
      }
    }
    if($name -eq 'logs'){
      $rows | Where-Object {$_.type -in @('INSTAGRAM_POST_ERROR','INSTAGRAM_POST_PUBLISHED','POST_UPLOADED','POST_QUEUED','WEEKLY_LAUNCH_ERROR')} | Sort-Object at -Descending | Select-Object -First 10 | ForEach-Object {
        'LOG type='+(SafeCode $_.type)+' stage='+(SafeCode $_.stage)+' status='+(SafeCode $_.status)+' attempt='+(SafeNumber $_.attempt)+' errorCategory='+(ErrorCategory $_.error)+' igHttp='+(ProviderHttp $_.error)+' igCode='+(ProviderCode $_.error)+' igSubcode='+(ProviderSubcode $_.error)
      }
    }
    if($name -eq 'tenants'){
      $rows | Where-Object {$_.id -eq 'system' -or $_.meta.connected -eq $true} | ForEach-Object {
        'CONNECTION system='+($_.id -eq 'system')+' connected='+($_.meta.connected -eq $true)+' source='+(SafeCode $_.meta.source)+' api='+(SafeCode $_.meta.instagramApi)+' metaTokenPresent='+([bool]($_.meta.accessToken -or $_.meta.metaAccessToken))+' igTokenPresent='+([bool]$_.meta.instagramAccessToken)+' pagePresent='+([bool]$_.meta.pageId)+' igIdPresent='+([bool]$_.meta.instagramUserId)+' adAccountPresent='+([bool]$_.meta.adAccountId)
      }
    }
  }catch{($name+': READ_ERROR')}
}
'READ_ONLY_DONE'
