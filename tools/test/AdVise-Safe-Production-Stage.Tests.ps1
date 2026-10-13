param([Parameter(Mandatory=$true)][string]$StageScript)
$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($StageScript,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Stage script has syntax errors.'}
$source=Get-Content -LiteralPath $StageScript -Raw -Encoding UTF8
$block=[scriptblock]::Create($source)
$root=Join-Path $env:RUNNER_TEMP ('advise staging fixture '+[guid]::NewGuid().ToString('N'))
$backend=Join-Path $root 'backend'
New-Item -ItemType Directory -Path (Join-Path $backend 'src'),(Join-Path $backend 'data'),(Join-Path $backend 'uploads') | Out-Null
[IO.File]::WriteAllText((Join-Path $backend '.env'),'META_ACCESS_TOKEN=STAGE_MUST_NOT_PRINT_OR_COPY_SECRET')
[IO.File]::WriteAllText((Join-Path $backend 'src/server.js'),'// Original production fixture')
[IO.File]::WriteAllText((Join-Path $backend 'data/tenants.json'),'{"token":"STAGE_MUST_NOT_PRINT_OR_COPY_SECRET"}')
[IO.File]::WriteAllText((Join-Path $backend 'uploads/original.jpg'),'fixture original media')
function Snapshot {
  return @(Get-ChildItem -LiteralPath $backend -Recurse -File | Sort-Object FullName | ForEach-Object {$_.FullName+':'+(Get-FileHash -LiteralPath $_.FullName).Hash})
}
function Assert-Unchanged {
  if(@(Compare-Object $script:before (Snapshot)).Count){throw 'Production fixture changed.'}
}
$before=Snapshot
$callerToken=$env:META_ACCESS_TOKEN
$callerData=$env:ADVISE_DATA_DIR
$callerCron=$env:CRON_ENABLED
$env:META_ACCESS_TOKEN='STAGE_MUST_NOT_PRINT_OR_COPY_SECRET'
$env:ADVISE_DATA_DIR=Join-Path $backend 'data'
$env:CRON_ENABLED='true'
$baselineCulture=[Threading.Thread]::CurrentThread.CurrentCulture
$baselineUICulture=[Threading.Thread]::CurrentThread.CurrentUICulture
try {
  foreach($culture in @('en-US','tr-TR')) {
    [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo($culture)
    [Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::GetCultureInfo($culture)
    $bad=(& $block -BackendPath $backend -StagePath (Join-Path $backend 'uploads/stage')) -join [Environment]::NewLine
    if(!$bad.Contains('STAGE_READY=False REASON=UNSAFE_STAGE_PATH')){throw 'Runtime subdirectory was accepted.'}
    Assert-Unchanged
    $existing=Join-Path $root ('_advise-stage-cb6a908-'+[guid]::NewGuid().ToString('N').Substring(0,12))
    New-Item -ItemType Directory -Path $existing | Out-Null
    $bad=(& $block -BackendPath $backend -StagePath $existing) -join [Environment]::NewLine
    if(!$bad.Contains('STAGE_READY=False REASON=STAGE_ALREADY_EXISTS')){throw 'Existing staging directory was accepted.'}
    Assert-Unchanged
  }
  # Full real staging on Windows PowerShell 5 with paths containing spaces.
  # No Meta calls: source archive download and npm install only.
  $result=@(& $block -BackendPath $backend)
  $text=$result -join [Environment]::NewLine
  if(!$text.Contains('STAGE_READY=True REVISION=cb6a908')){throw ('Staging failed: '+$text)}
  if($text.Contains('STAGE_MUST_NOT_PRINT_OR_COPY_SECRET')){throw 'Secret leaked to stdout.'}
  Assert-Unchanged
  if($env:META_ACCESS_TOKEN -cne 'STAGE_MUST_NOT_PRINT_OR_COPY_SECRET' -or $env:ADVISE_DATA_DIR -cne (Join-Path $backend 'data') -or $env:CRON_ENABLED -cne 'true'){throw 'Caller environment changed.'}
  $stage=($result | Where-Object {$_ -clike 'STAGE_PATH=*'}).Substring('STAGE_PATH='.Length)
  $manifest=Get-Content -LiteralPath (Join-Path $stage 'stage.json') -Raw | ConvertFrom-Json
  if(!$manifest.stagingOnly -or $manifest.revision -cne 'cb6a908426c80752936d6cab40a0c645f641d4ea'){throw 'Wrong manifest.'}
  $code=Join-Path $stage 'code'
  if(!(Test-Path -LiteralPath (Join-Path $stage 'npm-cache') -PathType Container)){throw 'npm cache was not isolated.'}
  foreach($path in @('.env','data','uploads')){
    if(Test-Path -LiteralPath (Join-Path $code $path)){throw 'Production runtime was copied.'}
  }
  foreach($path in @('src/server.js','src/automation-safety.js','package-lock.json','node_modules/sharp/package.json')){
    if(!(Test-Path -LiteralPath (Join-Path $code $path))){throw 'Required staged file missing.'}
  }
  if(!(Test-Path -LiteralPath (Join-Path $backend '.env'))){throw 'Original env missing.'}
  'STAGE_TEST_PS5_SYNTAX=PASS'
  'STAGE_TEST_RUNTIME_UNCHANGED=PASS'
  'STAGE_TEST_PATH_GUARDS_EN_US_TR_TR=PASS'
  'STAGE_TEST_NO_SECRET_COPY_OR_STDOUT=PASS'
  'STAGE_TEST_CALLER_ENV_UNCHANGED=PASS'
  'STAGE_TEST_WINDOWS_INSTALL_NATIVE_JPEG=PASS'
  'STAGE_TEST_NPM_CACHE_ISOLATED=PASS'
} finally {
  $env:META_ACCESS_TOKEN=$callerToken
  $env:ADVISE_DATA_DIR=$callerData
  $env:CRON_ENABLED=$callerCron
  [Threading.Thread]::CurrentThread.CurrentCulture=$baselineCulture
  [Threading.Thread]::CurrentThread.CurrentUICulture=$baselineUICulture
}
