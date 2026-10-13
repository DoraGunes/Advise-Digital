param([Parameter(Mandatory=$true)][string]$StageScript)
$ErrorActionPreference='Stop'
$source=Get-Content -LiteralPath $StageScript -Raw -Encoding UTF8
$root=Join-Path $env:RUNNER_TEMP ('advise downloads '+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $root 'src') | Out-Null
. ([scriptblock]::Create($source.Substring(0,$source.IndexOf('# EXECUTE_STAGE')))) -BackendPath $root
function Start-Sleep {param($Seconds)}
$script:calls=0;$script:behavior='GOOD'
function Invoke-WebRequest {
 param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$ErrorAction)
 $script:calls++
 if(!$Uri.StartsWith('https://raw.githubusercontent.com/DoraGunes/Advise-Digital/cb6a908426c80752936d6cab40a0c645f641d4ea/backend/')){throw 'Unpinned download.'}
 if($script:behavior -ceq 'RETRY' -and $script:calls -eq 1){throw (New-Object IO.IOException)}
 $bytes=[Text.Encoding]::UTF8.GetBytes('fixture source')
 if($script:behavior -ceq 'BAD_HASH'){$bytes=[Text.Encoding]::UTF8.GetBytes('tampered')}
 [IO.File]::WriteAllBytes($OutFile,$bytes)
}
$reference=Join-Path $root 'reference'
[IO.File]::WriteAllText($reference,'fixture source',(New-Object Text.UTF8Encoding($false)))
$hash=Get-BlobHash $reference
$script:behavior='RETRY'
Download-VerifiedStageFile @{path='backend/src/server.js';sha=$hash} $root
if($script:calls -ne 2 -or (Get-BlobHash (Join-Path $root 'src/server.js')) -cne $hash){throw 'Verified retry failed.'}
'DOWNLOAD_TEST=PinnedRawDownloadAndTransientRetry PASS'
$script:behavior='BAD_HASH';$script:calls=0
$caught=''
try{Download-VerifiedStageFile @{path='backend/src/meta.js';sha=$hash} $root}catch{$caught=$_.Exception.Message}
if($caught -cne 'SOURCE_HASH_FAILED' -or (Test-Path (Join-Path $root 'src/meta.js'))){throw 'Tampered source accepted.'}
'DOWNLOAD_TEST=HashMismatchNeverInstalled PASS'
$caught=''
try{Download-VerifiedStageFile @{path='backend/../.env';sha=$hash} $root}catch{$caught=$_.Exception.Message}
if($caught -cne 'SOURCE_FILE_MISSING'){throw 'Unsafe source path accepted.'}
'DOWNLOAD_TEST=SourcePathWhitelist PASS'
$before=$script:calls
$caught=''
try{Download-VerifiedStageFile @{path='backend/src/server.js';sha=$hash} $root}catch{$caught=$_.Exception.Message}
if($caught -cne 'SOURCE_STAGE_WRITE_FAILED' -or $script:calls -ne $before){throw 'Existing staging source overwritten.'}
'DOWNLOAD_TEST=ExistingFileNeverOverwritten PASS'
exit 0
