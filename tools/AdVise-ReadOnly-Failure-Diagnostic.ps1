# AdVise Digital – local, read-only troubleshooting. Never prints secrets.
# Usage: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\AdVise-ReadOnly-Failure-Diagnostic.ps1
param([string]$BackendPath='', [string]$DataPath='')

$ErrorActionPreference='Stop'
Write-Host '=== ADVISE READ-ONLY META + QUEUE DIAG ==='
try {
  $health=Invoke-RestMethod -Uri 'http://127.0.0.1:3001/health' -TimeoutSec 5
  Write-Host ('LOCAL_API=' + $health.ok + ' VERSION=' + $health.version + ' MARKER=' + $health.buildMarker + ' API=' + $health.apiVersion)
} catch { Write-Host ('LOCAL_API=UNAVAILABLE (' + $_.Exception.GetType().Name + ')') }

$candidates=@()
if ($BackendPath) { $candidates+= $BackendPath }
if ($env:ADVISE_BACKEND_ROOT) { $candidates+= $env:ADVISE_BACKEND_ROOT }
$candidates+= @(
  (Join-Path $env:USERPROFILE 'Desktop\AdVise AI-PROD-V16-20261006-121331\backend'),
  (Join-Path $env:USERPROFILE 'Desktop\AdVise AI-FINAL\backend'),
  (Join-Path $env:USERPROFILE 'Desktop\AdVise-Meta-Fix-Test\backend')
)
$found=$false
foreach($backend in ($candidates|Select-Object -Unique)) {
  if (-not(Test-Path (Join-Path $backend 'src\server.js'))) { continue }
  $paths=@()
  if($DataPath){$paths+= $DataPath}
  $envFile=Join-Path $backend '.env'
  if(Test-Path $envFile) {
    # Read only one non-secret setting. Never echo the .env contents.
    $match=Get-Content $envFile | Where-Object { $_ -match '^ADVISE_DATA_DIR\s*=' } | Select-Object -First 1
    if($match) {
      $raw=($match -split '=',2)[1].Trim().Trim('"',"'")
      if($raw){$paths+= $(if([System.IO.Path]::IsPathRooted($raw)){$raw}else{Join-Path $backend $raw})}
    }
  }
  if($env:ADVISE_DATA_DIR){$paths+= $env:ADVISE_DATA_DIR}
  $paths+= (Join-Path $backend 'data')
  foreach($p in ($paths|Select-Object -Unique)) {
    $opsFile=Join-Path $p 'ad_operations.json'
    $postsFile=Join-Path $p 'posts.json'
    if (-not(Test-Path $opsFile) -and -not(Test-Path $postsFile)){continue}
    $found=$true
    Write-Host ('BACKEND=' + $backend + ' DATA_PATH_FOUND=true')
    if(Test-Path $opsFile) {
      try{
        $raw=Get-Content -Raw -Encoding UTF8 $opsFile | ConvertFrom-Json
        $ops=@($raw | Sort-Object updatedAt -Descending | Select-Object -First 5)
        Write-Host ('AD_OPERATIONS=' + @($raw).Count)
        foreach($o in $ops){
          Write-Host ('AD: status=' + $o.status + ' stage=' + $o.stage + ' updated=' + $o.updatedAt +
            ' code=' + $o.failure.code + ' failureStage=' + $o.failure.stage +
            ' providerCode=' + $o.providerFailure.code +
            ' providerSubcode=' + $o.providerFailure.subcode +
            ' providerHttp=' + $o.providerFailure.status +
            ' createdParts=' + @($o.ids.PSObject.Properties).Count)
        }
      } catch {Write-Host ('AD_OPERATIONS_READ_ERROR=' + $_.Exception.GetType().Name)}
    }
    if(Test-Path $postsFile) {
      try{
        $raw=Get-Content -Raw -Encoding UTF8 $postsFile | ConvertFrom-Json
        $posts=@($raw)
        Write-Host ('POSTS_TOTAL=' + $posts.Count)
        foreach($g in ($posts | Group-Object publishStatus)) {Write-Host ('POSTS_STATUS=' + $g.Name + ' COUNT=' + $g.Count)}
        foreach($post in ($posts | Sort-Object createdAt -Descending | Select-Object -First 5)){
          $fileExists=$false
          if($post.filePath){$fileExists=Test-Path $post.filePath}
          $urlKind=if($post.publicUrl -match '^https://'){'HTTPS'}elseif($post.publicUrl){'NOT_HTTPS'}else{'NONE'}
          $hostName=''
          try{$hostName=([uri]$post.publicUrl).Host}catch{}
          Write-Host ('POST: type=' + $post.mediaType + ' status=' + $post.publishStatus +
            ' auto=' + $post.autoPublish + ' ai=' + $post.aiStatus +
            ' fileExists=' + $fileExists + ' url=' + $urlKind + ' host=' + $hostName +
            ' scheduled=' + $post.nextPublishAt +
            ' publishPhase=' + $post.publishPhase)
        }
      } catch {Write-Host ('POSTS_READ_ERROR=' + $_.Exception.GetType().Name)}
    }
    break
  }
  if($found){break}
}
if(-not $found){Write-Host 'DATA_NOT_FOUND – specify -BackendPath for the running production backend. No changes made.'}
Write-Host 'READ_ONLY_DONE – no files, tokens, Meta assets, ads or settings were modified.'
