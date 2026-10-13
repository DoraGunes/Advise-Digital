# Staging only. Never stops processes, starts the server, or writes production files.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$BackendPath,
  [string]$StagePath=''
)
$ErrorActionPreference='Stop'
$revision='162e259ee3dc938d492b15bc5d3f56115ae85696'
$repository='DoraGunes/Advise-Digital'
$stage=''
$reason='PREPARATION_FAILED'
$phase='PATH_GUARD'

function Assert-NoReparse([string]$Path) {
  $item=Get-Item -LiteralPath $Path
  while($null -ne $item) {
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'UNSAFE_PATH'}
    $item=$item.Parent
  }
}
function Get-BlobHash([string]$Path) {
  $bytes=[IO.File]::ReadAllBytes($Path)
  $header=[Text.Encoding]::UTF8.GetBytes('blob '+$bytes.Length+[char]0)
  $sha=[Security.Cryptography.SHA1]::Create()
  try {return ([BitConverter]::ToString($sha.ComputeHash([byte[]]($header+$bytes)))).Replace('-','').ToLowerInvariant()}
  finally {$sha.Dispose()}
}
function Invoke-StageProcess([string]$Executable,[string]$Arguments,[string]$WorkingDirectory,[string]$LogName) {
  # Child-only environment changes; the caller's environment is never changed.
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$Executable
  $info.Arguments=$Arguments
  $info.WorkingDirectory=$WorkingDirectory
  $info.UseShellExecute=$false
  $info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true
  $info.RedirectStandardError=$true
  foreach($key in @($info.EnvironmentVariables.Keys)) {
    if($key -match '^(META_|INSTAGRAM_|JWT_|ADMIN_|DATABASE_|GEMINI_|GOOGLE_|OPENAI_|ADVISE_|DOTENV_|NODE_OPTIONS$|PGPASSWORD$)') {
      $info.EnvironmentVariables.Remove([string]$key)
    }
  }
  $info.EnvironmentVariables['CRON_ENABLED']='false'
  $info.EnvironmentVariables['ADVISE_NO_LISTEN']='true'
  $info.EnvironmentVariables['ADVISE_DATA_DIR']=Join-Path $stage 'isolated-data'
  $info.EnvironmentVariables['ADVISE_UPLOAD_DIR']=Join-Path $stage 'isolated-uploads'
  $info.EnvironmentVariables['DOTENV_CONFIG_PATH']=Join-Path $stage 'no-production.env'
  $info.EnvironmentVariables['PATH']=$nodeDirectory+';'+$info.EnvironmentVariables['PATH']
  $process=New-Object Diagnostics.Process
  $process.StartInfo=$info
  try {
    $script:lastChildState='STAGE_CHILD executableExists='+(Test-Path -LiteralPath $info.FileName -PathType Leaf)+' workingDirectoryExists='+(Test-Path -LiteralPath $info.WorkingDirectory -PathType Container)+' nodeExecutable='+([IO.Path]::GetFileName($info.FileName) -ieq 'node.exe')
    [void]$process.Start()
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    # Do not kill any process on timeout. This child never runs server.js.
    if(!$process.WaitForExit(900000)){throw 'STAGING_CHILD_TIMEOUT'}
    $out=$stdout.GetAwaiter().GetResult()
    $err=$stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $stage $LogName),$out+[Environment]::NewLine+$err)
    if($process.ExitCode -ne 0){throw 'STAGING_CHILD_FAILED'}
    return $out.Trim()
  } finally {$process.Dispose()}
}
try {
  $backend=[IO.Path]::GetFullPath($BackendPath).TrimEnd('\','/')
  if(!(Test-Path -LiteralPath $backend -PathType Container)){throw 'BACKEND_NOT_FOUND'}
  Assert-NoReparse $backend
  $envFile=Join-Path $backend '.env'
  if(!(Test-Path -LiteralPath $envFile -PathType Leaf)){throw 'ENV_MISSING'}
  if(((Get-Item -LiteralPath $envFile).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'UNSAFE_PATH'}
  $envBefore=(Get-FileHash -LiteralPath $envFile -Algorithm SHA256).Hash
  if(!$StagePath) {
    $StagePath=Join-Path (Split-Path $backend -Parent) ('_advise-stage-162e259-'+[guid]::NewGuid().ToString('N').Substring(0,12))
  }
  $stage=[IO.Path]::GetFullPath($StagePath).TrimEnd('\','/')
  # Permit only a fresh sibling of the backend. Never allow a runtime subdirectory.
  if(![string]::Equals((Split-Path $stage -Parent),(Split-Path $backend -Parent),[StringComparison]::OrdinalIgnoreCase) -or
     [string]::Equals($stage,$backend,[StringComparison]::OrdinalIgnoreCase) -or
     (Split-Path $stage -Leaf) -cnotmatch '^_advise-stage-162e259-[a-f0-9]{12}$'){throw 'UNSAFE_STAGE_PATH'}
  if(Test-Path -LiteralPath $stage){throw 'STAGE_ALREADY_EXISTS'}
  $node=(Get-Command node.exe -CommandType Application).Source
  $nodeDirectory=Split-Path $node -Parent
  $npm=Join-Path $nodeDirectory 'npm.cmd'
  if(!(Test-Path -LiteralPath $npm -PathType Leaf)){throw 'NPM_NOT_FOUND'}
  New-Item -ItemType Directory -Path $stage | Out-Null
  $code=Join-Path $stage 'code'
  New-Item -ItemType Directory -Path (Join-Path $code 'src') | Out-Null
  $phase='NODE_PROBE'
  $version=Invoke-StageProcess $node '--version' $code 'node-version-local.log'
  if($version -notmatch '^v(\d+)\.' ){throw 'NODE_VERSION_UNSUPPORTED'}
  if([int]$Matches[1] -lt 20){throw 'NODE_VERSION_UNSUPPORTED'}
  [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $phase='SOURCE_DOWNLOAD'
  $tree=Invoke-RestMethod ('https://api.github.com/repos/'+$repository+'/git/trees/'+$revision+'?recursive=1') -Headers @{'User-Agent'='AdVise-Staging'} -TimeoutSec 60
  if($tree.sha -cne $revision -or $tree.truncated){throw 'SOURCE_MANIFEST_FAILED'}
  $files=@($tree.tree | Where-Object {$_.type -ceq 'blob' -and $_.path -cmatch '^backend/(src/[A-Za-z0-9_-]+\.js|package(?:-lock)?\.json)$'})
  if($files.Count -lt 20 -or @($files | Where-Object {$_.path -ceq 'backend/package-lock.json'}).Count -ne 1){throw 'SOURCE_MANIFEST_FAILED'}
  $zip=Join-Path $stage 'source.zip'
  Invoke-WebRequest -UseBasicParsing ('https://github.com/'+$repository+'/archive/'+$revision+'.zip') -OutFile $zip -TimeoutSec 300
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $phase='SOURCE_EXTRACT'
  $archive=[IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $root=($archive.Entries[0].FullName -split '/')[0]
    foreach($file in $files) {
      $entry=$archive.GetEntry($root+'/'+$file.path)
      if(!$entry){throw 'SOURCE_FILE_MISSING'}
      $target=Join-Path $code $file.path.Substring('backend/'.Length)
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$false)
      if((Get-BlobHash $target) -cne $file.sha){throw 'SOURCE_HASH_FAILED'}
    }
  } finally {$archive.Dispose()}
  'STAGE_SOURCE_VERIFIED=True'
  # Only npm.cmd ci is launched, through the Windows command interpreter.
  $arguments='/d /s /c ""'+$npm+'" ci --no-audit --no-fund"'
  $phase='DEPENDENCY_INSTALL'
  [void](Invoke-StageProcess $env:ComSpec $arguments $code 'install-local.log')
  'STAGE_WINDOWS_DEPENDENCIES=True'
  $phase='SYNTAX_CHECK'
  foreach($file in Get-ChildItem -LiteralPath (Join-Path $code 'src') -Filter '*.js' -File) {
    [void](Invoke-StageProcess $node ('--check "'+$file.FullName+'"') $code 'syntax-local.log')
  }
  $phase='NATIVE_PROBE'
  $nativeProbe=Join-Path $code 'native-probe.mjs'
  [IO.File]::WriteAllText($nativeProbe,"import sharp from 'sharp'; await sharp({create:{width:1,height:1,channels:3,background:'#ffffff'}}).jpeg().toBuffer();")
  [void](Invoke-StageProcess $node ('"'+$nativeProbe+'"') $code 'native-local.log')
  'STAGE_NATIVE_JPEG=True'
  # Detect source mutation by dependency hooks before declaring readiness.
  foreach($file in $files) {
    if((Get-BlobHash (Join-Path $code $file.path.Substring('backend/'.Length))) -cne $file.sha){throw 'SOURCE_HASH_FAILED'}
  }
  if(Test-Path -LiteralPath (Join-Path $code '.env')){throw 'UNEXPECTED_STAGE_ENV'}
  if((Get-FileHash -LiteralPath $envFile -Algorithm SHA256).Hash -cne $envBefore){throw 'PRODUCTION_ENV_CHANGED'}
  $phase='MANIFEST'
  $manifest=@{
    revision=$revision; backend=$backend; nodePath=$node; envHash=$envBefore
    sourceFiles=@($files | Select-Object path,sha); stagingOnly=$true
  }
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'stage.json') -Encoding UTF8
  'STAGE_PATH='+$stage
  'STAGE_READY=True REVISION=162e259'
} catch {
  $allowed=@('UNSAFE_PATH','BACKEND_NOT_FOUND','ENV_MISSING','UNSAFE_STAGE_PATH','STAGE_ALREADY_EXISTS','NPM_NOT_FOUND','NODE_VERSION_UNSUPPORTED','SOURCE_MANIFEST_FAILED','SOURCE_FILE_MISSING','SOURCE_HASH_FAILED','STAGING_CHILD_TIMEOUT','STAGING_CHILD_FAILED','UNEXPECTED_STAGE_ENV','PRODUCTION_ENV_CHANGED')
  if($allowed -ccontains $_.Exception.Message){$reason=$_.Exception.Message}
  if($script:lastChildState){$script:lastChildState}
  $inner=$_.Exception.InnerException
  $type=if($inner){$inner.GetType().Name}else{$_.Exception.GetType().Name}
  $native=if($inner -is [ComponentModel.Win32Exception]){$inner.NativeErrorCode}else{0}
  'STAGE_READY=False REASON='+$reason+' PHASE='+$phase+' LINE='+[int]$_.InvocationInfo.ScriptLineNumber+' TYPE='+$type+' NATIVE='+$native
}
'STAGING_ONLY_DONE'
