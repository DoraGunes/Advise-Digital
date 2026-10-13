param([Parameter(Mandatory=$true)][string]$TransitionScript)
$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($TransitionScript,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Transition PowerShell syntax failed.'}
$source=Get-Content -LiteralPath $TransitionScript -Raw -Encoding UTF8
$prefix=$source.Substring(0,$source.IndexOf('# EXECUTE_TRANSITION'))
$root=Join-Path $env:RUNNER_TEMP ('advise transition fixtures '+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
. ([scriptblock]::Create($prefix)) -BackendPath $root -StagePath $root -BackupPath $root
foreach($f in $releaseFiles) {
 if((Blob-Hash (Join-Path (Join-Path $env:GITHUB_WORKSPACE 'backend') $f.path)) -cne $f.sha){throw 'Pinned release ledger mismatch.'}
}
$script:RealCopy=(Get-Command Copy-Tree).ScriptBlock
function New-Fixture([string]$Name) {
 $base=Join-Path $root $Name
 $backend=Join-Path $base 'backend';$stage=Join-Path $base 'stage';$backup=Join-Path $base 'backup'
 foreach($p in @('src','node_modules','data','uploads')){New-Item -ItemType Directory -Path (Join-Path $backend $p) -Force | Out-Null}
 foreach($p in @('src','node_modules/sharp')){New-Item -ItemType Directory -Path (Join-Path $stage ('code/'+$p)) -Force | Out-Null}
 $files=@{
 '.env'='PRIVATE_FIXTURE_SECRET_NEVER_PRINT'
 'src/server.js'='old code'
 'node_modules/original.txt'='old deps'
 'package.json'='{"version":"old"}'
 'package-lock.json'='{"version":"old"}'
 'data/ad_operations.json'='[{"status":"FAILED","stage":"preflight"}]'
 'data/posts.json'='[{"id":"photo","publishStatus":"PUBLISHED","publishPhase":"CONFIRMED"}]'
 'data/users.json'='[{"id":"admin","role":"ADMIN","tenantId":"system","active":true}]'
 'data/tenants.json'='[{"id":"system","meta":{"connected":true,"accessToken":"PRIVATE_FIXTURE_SECRET_NEVER_PRINT","source":"OAUTH","adAccountId":"fixture-ad","pageId":"fixture-page","instagramUserId":"fixture-ig"}}]'
 'uploads/photo.jpg'='original media'
 }
 foreach($name in $files.Keys){[IO.File]::WriteAllText((Join-Path $backend $name),$files[$name])}
 [IO.File]::WriteAllText((Join-Path $stage 'code/src/server.js'),'new code')
 [IO.File]::WriteAllText((Join-Path $stage 'code/node_modules/sharp/package.json'),'{}')
 [IO.File]::WriteAllText((Join-Path $stage 'code/package.json'),'{"version":"new"}')
 [IO.File]::WriteAllText((Join-Path $stage 'code/package-lock.json'),'{"version":"new"}')
 New-Item -ItemType Directory -Path $backup | Out-Null
 Protect-Directory $backup
 $records=@()
 foreach($row in @(@{label='backend';source=$backend;exclude=@((Join-Path $backend 'data'),(Join-Path $backend 'uploads'))},@{label='runtime-data';source=(Join-Path $backend 'data');exclude=@()},@{label='runtime-uploads';source=(Join-Path $backend 'uploads');exclude=@()})) {
  Copy-Tree $row.source (Join-Path $backup $row.label) (Join-Path $backup ($row.label+'.log')) $row.exclude
  $records+=@{label=$row.label;source=$row.source;files=(Snapshot (Join-Path $backup $row.label))}
 }
 $birth=[datetime]'2026-10-13T01:00:00Z'
 $envHash=(Get-FileHash (Join-Path $backend '.env')).Hash
 @{backend=$backend;stage=$stage;oldPid=1796;oldCreationDate=$birth.ToUniversalTime().ToString('o');nodePath='fixture-node.exe';envHash=$envHash;records=$records;rollbackCodeOnly=$true} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $backup 'backup-receipt.json') -Encoding UTF8
 @{backend=$backend;stagingOnly=$true;revision='162e259ee3dc938d492b15bc5d3f56115ae85696'} | ConvertTo-Json | Set-Content (Join-Path $stage 'stage.json') -Encoding UTF8
 $ledger=@()
 foreach($path in @('src/server.js','package.json','package-lock.json')){$ledger+=@{path=$path;sha=(Blob-Hash (Join-Path $stage ('code/'+$path)))}}
 return @{backend=$backend;stage=$stage;backup=$backup;birth=$birth;ledger=$ledger;dataHash=(Get-FileHash (Join-Path $backend 'data/tenants.json')).Hash;envHash=$envHash}
}
$mocks=@'
function Assert-Admin {}
function Get-VerifiedProcess {
 if(!$script:state.alive -or $ExpectedPid -ne $script:state.pid){throw 'PID_CHANGED'}
 return @{process=[pscustomobject]@{CreationDate=$script:state.birth;ExecutablePath='fixture-node.exe'};facts=@($backend,$runtimeData,$runtimeUploads,'false')}
}
function Stop-VerifiedBackend([string]$Birth) {
 $v=Get-VerifiedProcess;Assert-Birth $v $Birth;Assert-Idle
 $script:state.stops++;$script:state.alive=$false
}
function Start-Backend {
 if($script:state.alive){throw 'PORT_BUSY'}
 $script:state.starts++;$script:state.pid=2000+$script:state.starts;$script:state.birth=[datetime]::UtcNow;$script:state.alive=$true
 return @{id=$script:state.pid;birth=$script:state.birth.ToUniversalTime().ToString('o')}
}
function Stop-StartedChild {
 if(!$journal.currentPid -or !$script:state.alive){return}
 if($journal.currentPid -ne $script:state.pid){throw 'PID_CHANGED'}
 $script:state.stops++;$script:state.alive=$false
}
function Assert-Health {
 if(!$script:state.alive){throw 'HEALTH_FAILED'}
 if($script:case -ceq 'HealthFail' -and (Get-Content (Join-Path $backend 'src/server.js') -Raw) -ceq 'new code'){throw 'HEALTH_FAILED'}
}
function Assert-ReadOnlyApi {
 $script:state.smokes++
 if($script:case -ceq 'RuntimeChanged'){[IO.File]::WriteAllText((Join-Path $runtimeData 'new-current-record.json'),'keep current record')}
}
function Copy-Tree([string]$From,[string]$To,[string]$Log,[string[]]$Exclude=@()) {
 if($script:case -ceq 'CopyFail' -and $To -ceq (Join-Path $backend 'src') -and $From.StartsWith($stage,[StringComparison]::OrdinalIgnoreCase)){throw 'COPY_FAILED'}
 & $script:RealCopy $From $To $Log $Exclude
}
'@
function Invoke-Fixture($f,[string]$Mode,[string]$Case) {
 $script:case=$Case
 $actualLedger=[regex]::Match($source,'(?s)\$releaseFiles=@''\r?\n(.*?)\r?\n''@').Groups[1].Value
 if(!$actualLedger){throw 'Ledger block not found.'}
 $newLedger=$f.ledger | ConvertTo-Json -Compress
 $fixtureSource=$source.Replace($actualLedger,$newLedger).Replace('# EXECUTE_TRANSITION',$mocks+[Environment]::NewLine+'# EXECUTE_TRANSITION')
 $output=@(& ([scriptblock]::Create($fixtureSource)) -Mode $Mode -BackendPath $f.backend -StagePath $f.stage -BackupPath $f.backup -ExpectedPid 1796)
 $text=$output -join [Environment]::NewLine
 if($text.Contains('PRIVATE_FIXTURE_SECRET_NEVER_PRINT')){throw 'Secret leaked.'}
 if((Get-FileHash (Join-Path $f.backend '.env')).Hash -cne $f.envHash){throw 'Env changed.'}
 if((Get-FileHash (Join-Path $f.backend 'data/tenants.json')).Hash -cne $f.dataHash){throw 'Connection data changed.'}
 if((Get-Content (Join-Path $f.backend 'uploads/photo.jpg') -Raw) -cne 'original media'){throw 'Upload changed.'}
 return $text
}
foreach($case in @('DeployAndRollback','CopyFail','HealthFail','RuntimeChanged','StageTamper','PidDrift')) {
 $f=New-Fixture $case
 $script:state=@{alive=$true;pid=1796;birth=$f.birth;stops=0;starts=0;smokes=0}
 if($case -ceq 'StageTamper'){[IO.File]::WriteAllText((Join-Path $f.stage 'code/src/server.js'),'tampered')}
 if($case -ceq 'PidDrift'){$script:state.pid=9999}
 $result=Invoke-Fixture $f 'Deploy' $case
 if($case -cin @('StageTamper','PidDrift')) {
  if(!$result.Contains('TRANSITION_RESULT=NOT_APPLIED') -or $script:state.stops -ne 0){throw ('Unsafe preflight: '+$case)}
 } elseif($case -ceq 'DeployAndRollback') {
  if(!$result.Contains('TRANSITION_RESULT=DEPLOYED')){throw ('Deploy failed: '+$result)}
  [IO.File]::WriteAllText((Join-Path $f.backend 'data/new-after-deploy.json'),'new durable record')
  $result=Invoke-Fixture $f 'Rollback' $case
  if(!$result.Contains('TRANSITION_RESULT=ROLLED_BACK')){throw ('Manual rollback failed: '+$result)}
  if((Get-Content (Join-Path $f.backend 'data/new-after-deploy.json') -Raw) -cne 'new durable record'){throw 'Manual rollback overwrote runtime.'}
 } else {
  if(!$result.Contains('TRANSITION_RESULT=ROLLED_BACK')){throw ('Automatic rollback failed: '+$case+' '+$result)}
  if($case -ceq 'RuntimeChanged' -and !(Test-Path (Join-Path $f.backend 'data/new-current-record.json'))){throw 'Automatic rollback overwrote runtime.'}
 }
 if($case -cne 'PidDrift' -and !$script:state.alive){throw 'Backend was not recovered.'}
 if((Get-Content (Join-Path $f.backend 'src/server.js') -Raw) -cne 'old code'){throw ('Old code not restored: '+$case)}
 'TRANSITION_TEST='+$case+' PASS'
}
$f=New-Fixture 'StartEnvironment'
$backend=$f.backend;$receipt=@{nodePath='fixture-node.exe'};$runtimeData=Join-Path $backend 'data';$runtimeUploads=Join-Path $backend 'uploads';$journal=@{work=$f.backup}
$priorCron=$env:CRON_ENABLED;$env:CRON_ENABLED='true'
function Get-NetTCPConnection {return @()}
function Start-Process {
 param($FilePath,$ArgumentList,$WorkingDirectory,$RedirectStandardOutput,$RedirectStandardError,[switch]$PassThru)
 if($env:CRON_ENABLED -cne 'false' -or $env:ADVISE_NO_LISTEN -cne 'false' -or $env:PORT -cne '3001' -or $env:DOTENV_CONFIG_PATH -cne (Join-Path $backend '.env')){throw 'Unsafe child environment.'}
 $p=[pscustomobject]@{Id=2020;StartTime=[datetime]::UtcNow}
 $p | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
 return $p
}
try {
 [void](Start-Backend)
 if($env:CRON_ENABLED -cne 'true'){throw 'Caller environment not restored.'}
} finally {$env:CRON_ENABLED=$priorCron}
'TRANSITION_TEST=AutomationDisabledAndCallerEnvironmentPreserved PASS'
$script:apiCalls=0
function Mint-ReadOnlyToken {return 'synthetic.readonly.jwt'}
function Invoke-RestMethod {
 param($Uri,$Method,$Headers,[switch]$DisableKeepAlive,$TimeoutSec)
 if($Method -cne 'Get' -or !$Uri.StartsWith('http://127.0.0.1:3001/')){throw 'Non-read-only request.'}
 $script:apiCalls++
 switch($Uri){
 'http://127.0.0.1:3001/api/me' {return @{user=@{tenantId='system';role='ADMIN'}}}
 'http://127.0.0.1:3001/api/meta/status' {return @{connected=$true;metaTokenReady=$true;instagramTokenReady=$true;source='OAUTH';adAccountId='fixture-ad';pageId='fixture-page';instagramUserId='fixture-ig'}}
 'http://127.0.0.1:3001/api/posts' {return @{data=@(@{id='photo'})}}
 default {throw 'Unexpected API endpoint.'}
 }
}
Assert-ReadOnlyApi
if($script:apiCalls -ne 3){throw 'Missing read-only smoke.'}
'TRANSITION_TEST=LocalGetOnlyApiSmoke PASS'
'TRANSITION_TEST=PowerShell5SyntaxAndPinnedReleaseLedger PASS'

# robocopy exit 1 means successful copy, not a failed fixture test.
exit 0
