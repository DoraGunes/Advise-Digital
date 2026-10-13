# Controlled code-only transition. No provider writes or runtime restore.
[CmdletBinding()]
param(
 [ValidateSet('Validate','Deploy','Rollback')][string]$Mode='Validate',
 [Parameter(Mandatory=$true)][string]$BackendPath,
 [Parameter(Mandatory=$true)][string]$StagePath,
 [Parameter(Mandatory=$true)][string]$BackupPath,
 [int]$ExpectedPid=1796
)
$ErrorActionPreference='Stop'
$phase='PRECHECK'
$stopped=$false
$journal=$null
$releaseFiles=@'
[{"path":"package-lock.json","sha":"e783751d703e1856c670ffc43c5b99c7ee82324d"},{"path":"package.json","sha":"97a730b3fbf4c93570cb59b2a84b700a4ddad42b"},{"path":"src/ad-operations.js","sha":"ae90862e769f3274ffcb1addbb8ca4aba9baa8fc"},{"path":"src/ad-targeting.js","sha":"0fb8c4d47163f1928b7ccc73e7deec0d059273bd"},{"path":"src/ai-memory.js","sha":"ee7cb53a146711dfd1893cd04a45cb873e52f868"},{"path":"src/ai.js","sha":"86787461eba5f12e0f980673f041cac8a32d7946"},{"path":"src/auth.js","sha":"e2ea3d56d9d376c937a885b0929a212291b43d4a"},{"path":"src/automation-safety.js","sha":"fa2025a2b7e6883678f2f6549744b1e8349c5b14"},{"path":"src/config.js","sha":"bd06f1587fe592a13fdf815cd8b150ac658bd7ce"},{"path":"src/content-quality.js","sha":"1bfd911faf94a5825d0da96242e1db38e48eec4d"},{"path":"src/copy-style.js","sha":"4741b958257f0ac152657b18694762e2bb6195eb"},{"path":"src/cover-image.js","sha":"3bddd87bc86e2add0b8c25be3af0940d2a79b20d"},{"path":"src/db.js","sha":"592fd066ff21f4545ec6c3c14e409e7c356a871a"},{"path":"src/gemini-ads.js","sha":"f5f081896c90ac63522193c0b5c4551f8829f39c"},{"path":"src/hashtag-strategy.js","sha":"836695df9c23bcc4d670552efac768687f2f389b"},{"path":"src/instagram-image.js","sha":"de82bbafc1e64cb20c351dc6dc4faa7522036b62"},{"path":"src/meta-oauth.js","sha":"0b3aee614f3455f76bad009f2ef10a2ed1add713"},{"path":"src/meta.js","sha":"7378dc0cdbcf2d6129603d74d8bfc3deb0cb073f"},{"path":"src/operation-budget.js","sha":"d0768db500006029aa0f580ed8fccdb417bd6c3c"},{"path":"src/optimizer.js","sha":"a1dff2203774d5e13963e0d7990385b21c8835cc"},{"path":"src/performance-memory.js","sha":"7339b5123988b738e39321e4dfae054109bf8946"},{"path":"src/persistence.js","sha":"7b315f9a03e45cd4bde571e6bc2a042106d235c1"},{"path":"src/pro.js","sha":"0dccedffa1c35e9cf0ab68d27720ad90ce9dada0"},{"path":"src/product.js","sha":"4492c377975d5ab1064ba9e1f8a0b70b1f547c48"},{"path":"src/rules.js","sha":"a505185179f6505e788daf5bafe08039a9b9b7c0"},{"path":"src/scheduler.js","sha":"04b0a9e2e3910be90487b9030c0a5ae14666b2d9"},{"path":"src/server.js","sha":"f94f44f7ac40eddc50ad4077e9298aaa7622b0e1"},{"path":"src/store.js","sha":"ecd3cf34cacc7eb73e874d048445c127eaa30236"},{"path":"src/v78.js","sha":"288efc80fab90fbbf34e912dc439a80a743cea03"}]
'@ | ConvertFrom-Json
function Assert-PlainPath([string]$Path) {
 $item=Get-Item -LiteralPath $Path
 while($null -ne $item) {
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH'}
  $item=$item.Parent
 }
}
function Snapshot([string]$Root,[string[]]$Exclude=@()) {
 Assert-PlainPath $Root
 $rows=@()
 foreach($item in Get-ChildItem -LiteralPath $Root -Recurse -Force) {
  $ignored=$false
  foreach($skip in $Exclude) {
   if([string]::Equals($item.FullName,$skip,[StringComparison]::OrdinalIgnoreCase) -or $item.FullName.StartsWith($skip+'\',[StringComparison]::OrdinalIgnoreCase)){$ignored=$true;break}
  }
  if($ignored){continue}
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'REPARSE_PATH'}
  if(!$item.PSIsContainer) {
   $rows+=@{relative=$item.FullName.Substring($Root.Length).TrimStart('\');hash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash;size=$item.Length}
  }
 }
 return @($rows | Sort-Object { $_.relative })
}
function Same-Snapshot($Left,$Right) {
 $a=@($Left | ForEach-Object {$_.relative+'|'+$_.size+'|'+$_.hash})
 $b=@($Right | ForEach-Object {$_.relative+'|'+$_.size+'|'+$_.hash})
 if($a.Count -ne $b.Count){return $false}
 if($a.Count -eq 0){return $true}
 return @((Compare-Object $a $b)).Count -eq 0
}
function Copy-Tree([string]$From,[string]$To,[string]$Log,[string[]]$Exclude=@()) {
 $arguments=@($From,$To,'/E','/COPY:DAT','/DCOPY:DAT','/R:1','/W:1','/XJ','/NFL','/NDL','/NP','/NJH','/NJS')
 if($Exclude.Count){$arguments+=@('/XD')+$Exclude}
 & "$env:SystemRoot\System32\robocopy.exe" @arguments *> $Log
 if($LASTEXITCODE -ge 8){throw 'COPY_FAILED'}
}
function Protect-Directory([string]$Path) {
 $acl=New-Object Security.AccessControl.DirectorySecurity
 $acl.SetAccessRuleProtection($true,$false)
 $owner=[Security.Principal.WindowsIdentity]::GetCurrent().User
 $acl.SetOwner($owner)
 foreach($sid in @($owner,(New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'),(New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'))) {
  $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
  $acl.AddAccessRule($rule)
 }
 Set-Acl -LiteralPath $Path -AclObject $acl
 $check=Get-Acl -LiteralPath $Path
 if(!$check.AreAccessRulesProtected){throw 'PRIVATE_BACKUP_ACL_FAILED'}
 $allowed=@($owner.Value,'S-1-5-18','S-1-5-32-544')
 foreach($rule in $check.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
  if($rule.AccessControlType -eq 'Allow' -and $allowed -notcontains $rule.IdentityReference.Value){throw 'PRIVATE_BACKUP_ACL_FAILED'}
 }
}
if(-not ('AdViseTransitionProcess' -as [type])) {
 Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class AdViseTransitionProcess {
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int id);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")] static extern bool IsWow64Process(IntPtr h,out bool wow);
 [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int n,out IntPtr read);
 [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h,int info,IntPtr[] data,int size,out int returned);
 static byte[] Read(IntPtr h,long address,int count){var b=new byte[count];IntPtr n;if(!ReadProcessMemory(h,new IntPtr(address),b,count,out n)||n.ToInt64()!=count)throw new Exception();return b;}
 public static string[] Facts(int id){
  if(!Environment.Is64BitProcess)throw new Exception();
  IntPtr h=OpenProcess(0x410,false,id);if(h==IntPtr.Zero)throw new Exception();
  try {
   bool wow;if(!IsWow64Process(h,out wow)||wow)throw new Exception();
   var info=new IntPtr[6];int returned;if(NtQueryInformationProcess(h,0,info,48,out returned)!=0)throw new Exception();
   long parameters=BitConverter.ToInt64(Read(h,info[1].ToInt64()+0x20,8),0);
   var directory=Read(h,parameters+0x38,16);int length=BitConverter.ToUInt16(directory,0);
   if(length<2||length>8192||length%2!=0)throw new Exception();
   string cwd=Encoding.Unicode.GetString(Read(h,BitConverter.ToInt64(directory,8),length));
   long env=BitConverter.ToInt64(Read(h,parameters+0x80,8),0);
   var current=new StringBuilder();string data="",uploads="",cron="";bool ended=false;
   // Read only within the target process. Retain only two runtime path settings.
   for(int i=0;i<65536;i++){
    char c=(char)BitConverter.ToUInt16(Read(h,env+2L*i,2),0);
    if(c=='\0'){
     if(current.Length==0){ended=true;break;}
     string row=current.ToString();current.Clear();
     if(row.StartsWith("ADVISE_DATA_DIR=",StringComparison.OrdinalIgnoreCase))data=row.Substring(16);
     if(row.StartsWith("ADVISE_UPLOAD_DIR=",StringComparison.OrdinalIgnoreCase))uploads=row.Substring(18);
     if(row.StartsWith("CRON_ENABLED=",StringComparison.OrdinalIgnoreCase))cron=row.Substring(13);
    }else current.Append(c);
   }
   if(!ended)throw new Exception();
   return new string[]{cwd,data,uploads,cron};
  }finally{CloseHandle(h);}
 }
}
'@
}
function Get-VerifiedProcess {
 $ids=@(Get-NetTCPConnection -State Listen -LocalPort 3001 | Select-Object -ExpandProperty OwningProcess -Unique)
 if($ids.Count -ne 1 -or $ids[0] -ne $ExpectedPid){throw 'PID_CHANGED'}
 $p=Get-CimInstance Win32_Process -Filter ('ProcessId='+$ExpectedPid)
 if(!$p -or $p.Name -ine 'node.exe' -or !$p.ExecutablePath -or !$p.CommandLine){throw 'PROCESS_UNVERIFIED'}
 $facts=[AdViseTransitionProcess]::Facts($ExpectedPid)
 if(![string]::Equals($facts[0].TrimEnd([char[]]@('\','/')),$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'BACKEND_PATH_MISMATCH'}
 if($p.CommandLine -notmatch '(?i)(?:^|[\s"''])src[\\/]server\.js(?:$|[\s"''])' -and
    $p.CommandLine.IndexOf((Join-Path $backend 'src\server.js'),[StringComparison]::OrdinalIgnoreCase) -lt 0 -and
    $p.CommandLine.IndexOf(($backend.Replace('\','/')+'/src/server.js'),[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'LAUNCH_UNVERIFIED'}
 return @{process=$p;facts=$facts}
}

function Assert-Admin {
 if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'ADMIN_REQUIRED'}
}
function Blob-Hash([string]$Path) {
 $bytes=[IO.File]::ReadAllBytes($Path);$head=[Text.Encoding]::UTF8.GetBytes('blob '+$bytes.Length+[char]0)
 $hash=[Security.Cryptography.SHA1]::Create()
 try {return ([BitConverter]::ToString($hash.ComputeHash([byte[]]($head+$bytes)))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
}
function Assert-Stage {
 $m=Get-Content -LiteralPath (Join-Path $stage 'stage.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if(!$m.stagingOnly -or $m.revision -cne '162e259ee3dc938d492b15bc5d3f56115ae85696' -or ![string]::Equals($m.backend,$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'STAGE_CHANGED'}
 foreach($f in $releaseFiles) {
  $path=Join-Path (Join-Path $stage 'code') $f.path
  Assert-PlainPath $path
  if((Blob-Hash $path) -cne $f.sha){throw 'STAGE_CHANGED'}
 }
 if(!(Test-Path -LiteralPath (Join-Path $stage 'code/node_modules/sharp/package.json'))){throw 'STAGE_DEPENDENCIES_MISSING'}
 $expected=@($releaseFiles | Where-Object {$_.path.StartsWith('src/')} | ForEach-Object {$_.path.Substring(4)})
 $actual=@(Get-ChildItem -LiteralPath (Join-Path $stage 'code/src') -Recurse -File -Force | ForEach-Object {$_.FullName.Substring((Join-Path $stage 'code/src').Length).TrimStart('\').Replace('\','/')})
 if(@(Compare-Object $expected $actual).Count){throw 'STAGE_CHANGED'}
}
function Save-Journal {
 $journal | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $journalFile -Encoding UTF8
}
function Assert-Birth($Verified,[string]$Birth) {
 if($Verified.process.CreationDate.ToUniversalTime().ToString('o') -cne $Birth){throw 'PID_CHANGED'}
}
function Assert-Idle {
 $opsFile=Join-Path $runtimeData 'ad_operations.json'
 if(Test-Path -LiteralPath $opsFile) {
  $ops=Get-Content -LiteralPath $opsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach($op in $ops) {if(@('FAILED','SUCCEEDED','PARTIAL_FAILED') -cnotcontains ([string]$op.status).ToUpperInvariant()){throw 'OPERATION_IN_PROGRESS'}}
 }
 $postsFile=Join-Path $runtimeData 'posts.json'
 if(Test-Path -LiteralPath $postsFile) {
  $posts=Get-Content -LiteralPath $postsFile -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach($post in $posts) {
   if(@('PUBLISHING','RECONCILE') -ccontains ([string]$post.publishStatus).ToUpperInvariant() -or @('SUBMITTING','RECONCILE') -ccontains ([string]$post.publishPhase).ToUpperInvariant()){throw 'PUBLISH_IN_PROGRESS'}
  }
 }
}
function Stop-VerifiedBackend([string]$Birth) {
 $v=Get-VerifiedProcess
 Assert-Birth $v $Birth
 Assert-Idle
 $connections=@(Get-NetTCPConnection -OwningProcess $ExpectedPid -State Established -ErrorAction SilentlyContinue)
 if($connections.Count){throw 'ACTIVE_CONNECTIONS'}
 $p=Get-Process -Id $ExpectedPid
 if([Math]::Abs(($p.StartTime.ToUniversalTime()-$v.process.CreationDate.ToUniversalTime()).TotalMilliseconds) -gt 1){throw 'PID_CHANGED'}
 # Only the checked process object is terminated; never taskkill/all-node.
 $journal.stopRequested=$true;Save-Journal
 $p.Kill()
 if(!$p.WaitForExit(10000)){throw 'STOP_FAILED'}
 $left=@(Get-NetTCPConnection -State Listen -LocalPort 3001 -ErrorAction SilentlyContinue)
 if($left.Count){throw 'PORT_BUSY'}
}
function Start-Backend {
 if(@(Get-NetTCPConnection -State Listen -LocalPort 3001 -ErrorAction SilentlyContinue).Count){throw 'PORT_BUSY'}
 $names=@('CRON_ENABLED','ADVISE_NO_LISTEN','ADVISE_DATA_DIR','ADVISE_UPLOAD_DIR','DOTENV_CONFIG_PATH','PORT')
 $saved=@{}
 foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
 try {
  $env:CRON_ENABLED='false';$env:ADVISE_NO_LISTEN='false';$env:PORT='3001'
  $env:ADVISE_DATA_DIR=$runtimeData;$env:ADVISE_UPLOAD_DIR=$runtimeUploads
  $env:DOTENV_CONFIG_PATH=Join-Path $backend '.env'
  $tag=[guid]::NewGuid().ToString('N')
  $p=Start-Process -FilePath $receipt.nodePath -ArgumentList 'src/server.js' -WorkingDirectory $backend -RedirectStandardOutput (Join-Path $journal.work ('stdout-'+$tag+'.log')) -RedirectStandardError (Join-Path $journal.work ('stderr-'+$tag+'.log')) -PassThru
  $p.Refresh()
  return @{id=$p.Id;birth=$p.StartTime.ToUniversalTime().ToString('o')}
 } finally {foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
}
function Assert-Health {
 $ok=$false
 for($i=0;$i -lt 30;$i++) {
  try {
   $h=Invoke-RestMethod 'http://127.0.0.1:3001/health' -Method Get -DisableKeepAlive -TimeoutSec 2
   if($h.ok -eq $true -and $h.apiVersion -eq 16 -and $h.capabilities.adCreateSaga -eq $true){$ok=$true;break}
  } catch {}
  Start-Sleep -Milliseconds 500
 }
 if(!$ok){throw 'HEALTH_FAILED'}
 $v=Get-VerifiedProcess
 # Compare StartTime and CIM CreationDate at microsecond precision.
 if([Math]::Abs(($v.process.CreationDate.ToUniversalTime()-[datetime]::Parse($journal.currentBirth).ToUniversalTime()).TotalMilliseconds) -gt 1){throw 'PID_CHANGED'}
 if($v.facts[3] -cne 'false'){throw 'AUTOMATION_NOT_DISABLED'}
}
function Mint-ReadOnlyToken {
 $probe=Join-Path $journal.work 'read-only-token.cjs'
 $text=@'
const fs=require('node:fs');
const {createRequire}=require('node:module');
const req=createRequire(process.cwd()+'/package.json');
req('dotenv').config({path:process.cwd()+'/.env'});
const users=JSON.parse(fs.readFileSync(process.env.ADVISE_DATA_DIR+'/users.json','utf8'));
const user=users.find(u=>u.role==='ADMIN'&&u.active!==false&&u.tenantId==='system');
if(!user||!process.env.JWT_SECRET)process.exit(2);
process.stdout.write(req('jsonwebtoken').sign({sub:user.id,username:user.username,role:user.role,tenantId:'system'},process.env.JWT_SECRET,{expiresIn:'2m'}));
'@
 [IO.File]::WriteAllText($probe,$text)
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$receipt.nodePath;$info.Arguments='"'+$probe+'"';$info.WorkingDirectory=$backend
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.EnvironmentVariables['ADVISE_DATA_DIR']=$runtimeData
 $info.EnvironmentVariables['DOTENV_CONFIG_PATH']=Join-Path $backend '.env'
 $p=New-Object Diagnostics.Process;$p.StartInfo=$info
 try {
  [void]$p.Start()
  $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit(10000)){throw 'TOKEN_PROBE_FAILED'}
  $token=$out.GetAwaiter().GetResult().Trim()
  [void]$err.GetAwaiter().GetResult()
  if($p.ExitCode -ne 0 -or $token -cnotmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'){throw 'TOKEN_PROBE_FAILED'}
  return $token
 } finally {$p.Dispose()}
}
function Assert-ReadOnlyApi {
 $token=Mint-ReadOnlyToken
 try {
  $headers=@{Authorization='Bearer '+$token}
  $me=Invoke-RestMethod 'http://127.0.0.1:3001/api/me' -Method Get -Headers $headers -DisableKeepAlive -TimeoutSec 5
  $meta=Invoke-RestMethod 'http://127.0.0.1:3001/api/meta/status' -Method Get -Headers $headers -DisableKeepAlive -TimeoutSec 5
  $posts=Invoke-RestMethod 'http://127.0.0.1:3001/api/posts' -Method Get -Headers $headers -DisableKeepAlive -TimeoutSec 5
  if($me.user.tenantId -cne 'system' -or $me.user.role -cne 'ADMIN'){throw 'API_CHECK_FAILED'}
  $tenants=Get-Content -LiteralPath (Join-Path $runtimeData 'tenants.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $saved=$tenants | Where-Object {$_.id -ceq 'system'} | Select-Object -First 1
  # /api/meta/status tokenReady flags see the sanitized publicTenant object.
  # Read token presence only as booleans from the protected local record.
  $hasMetaToken=[bool]($saved.meta.accessToken -or $saved.meta.metaAccessToken)
  $hasInstagramToken=[bool]$saved.meta.instagramAccessToken
  if(!$saved.meta.connected -or !$meta.connected -or !$hasMetaToken -or !$hasInstagramToken -or
     $me.tenant.id -cne 'system' -or !$me.tenant.meta.hasAccessToken -or !$me.tenant.meta.hasInstagramAccessToken){throw 'CONNECTION_CHECK_FAILED'}
  foreach($key in @('adAccountId','pageId','instagramUserId','source')){
   if([string]$meta.$key -cne [string]$saved.meta.$key){throw 'CONNECTION_CHECK_FAILED'}
  }
  $local=Get-Content -LiteralPath (Join-Path $runtimeData 'posts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  # Match store.getPosts('system'): absent/empty tenantId belongs to system.
  $localIds=@($local | Where-Object {!$_.tenantId -or ([string]$_.tenantId -ceq 'system')} | ForEach-Object {$_.id})
  $apiIds=@($posts.data | ForEach-Object {$_.id})
  if($localIds.Count -ne $apiIds.Count -or ($localIds.Count -gt 0 -and @(Compare-Object $localIds $apiIds).Count)){throw 'RECORD_CHECK_FAILED'}
 } finally {$token=$null;$headers=$null;$me=$null;$meta=$null;$posts=$null;$saved=$null;$tenants=$null;$local=$null}
}
function Snapshot-QuiescedRuntime {
 $baseline=@()
 $snapshotRoot=Join-Path $journal.work ('runtime-snapshot-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
 foreach($row in $runtimeRecords) {
  $target=Join-Path $snapshotRoot $row.label
  $before=Snapshot $row.source
  Copy-Tree $row.source $target (Join-Path $journal.work ($row.label+'-copy.log'))
  if(!(Same-Snapshot $before (Snapshot $row.source)) -or !(Same-Snapshot $before (Snapshot $target))){throw 'CUTOVER_BACKUP_FAILED'}
  $baseline+=@{source=$row.source;files=$before}
 }
 $journal.baseline=$baseline
 Save-Journal
}
function Assert-RuntimePreserved {
 foreach($row in $journal.baseline){if(!(Same-Snapshot $row.files (Snapshot $row.source))){throw 'RUNTIME_CHANGED'}}
 if((Get-FileHash -LiteralPath (Join-Path $backend '.env')).Hash -cne $receipt.envHash){throw 'ENV_CHANGED'}
}
function Swap-Code {
 foreach($name in @('src','node_modules','package.json','package-lock.json')) {
  $part=@{name=$name;moved=$false}
  $journal.parts+=@($part);Save-Journal
  Move-Item -LiteralPath (Join-Path $backend $name) -Destination (Join-Path $journal.oldCode $name)
  $part.moved=$true;Save-Journal
  $source=Join-Path (Join-Path $stage 'code') $name
  $target=Join-Path $backend $name
  if(Test-Path -LiteralPath $source -PathType Container){Copy-Tree $source $target (Join-Path $journal.work ('install-'+$name+'.log'))}
  else {Copy-Item -LiteralPath $source -Destination $target}
 }
 Assert-Stage
 foreach($f in $releaseFiles){if((Blob-Hash (Join-Path $backend $f.path)) -cne $f.sha){throw 'INSTALLED_CODE_CHANGED'}}
}
function Restore-CodeOnly {
 $failed=Join-Path $journal.work ('failed-code-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $failed | Out-Null
 foreach($part in $journal.parts) {
  if(!$part.moved){continue}
  if(@('src','node_modules','package.json','package-lock.json') -cnotcontains $part.name){throw 'JOURNAL_INVALID'}
  $live=Join-Path $backend $part.name;$old=Join-Path $journal.oldCode $part.name
  if(!(Test-Path -LiteralPath $old)){throw 'OLD_CODE_MISSING'}
  if(Test-Path -LiteralPath $live){Move-Item -LiteralPath $live -Destination (Join-Path $failed $part.name)}
  Move-Item -LiteralPath $old -Destination $live
  $part.moved=$false;Save-Journal
 }
 if(!(Same-Snapshot $codeRecord.files (Snapshot $backend @($runtimeRecords | ForEach-Object {$_.source})))){throw 'ROLLBACK_CODE_CHECK_FAILED'}
 # No runtime, .env, uploads or connection records are restored from an old backup.
}
function Stop-StartedChild {
 if(!$journal.currentPid){return}
 $p=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$journal.currentPid)
 if(!$p){return}
 if($p.Name -ine 'node.exe' -or ![string]::Equals($p.ExecutablePath,$receipt.nodePath,[StringComparison]::OrdinalIgnoreCase) -or
    [Math]::Abs(($p.CreationDate.ToUniversalTime()-[datetime]::Parse($journal.currentBirth).ToUniversalTime()).TotalMilliseconds) -gt 1){throw 'PID_CHANGED'}
 $facts=[AdViseTransitionProcess]::Facts([int]$journal.currentPid)
 if(![string]::Equals($facts[0].TrimEnd([char[]]@('\','/')),$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'PID_CHANGED'}
 $process=Get-Process -Id ([int]$journal.currentPid)
 $process.Kill()
 if(!$process.WaitForExit(10000)){throw 'STOP_FAILED'}
}
function Recover-OldBackend {
 'TRANSITION_PHASE=ROLLBACK'
 Stop-StartedChild
 # Snapshot the latest runtime for rollback; never restore an older data snapshot.
 if(@($journal.parts | Where-Object {$_.moved}).Count -gt 0){Snapshot-QuiescedRuntime}
 Restore-CodeOnly
 $started=Start-Backend
 $journal.currentPid=$started.id;$journal.currentBirth=$started.birth
 $ExpectedPid=$started.id
 $journal.status='ROLLED_BACK';Save-Journal
 Assert-Health
 if($journal.baseline.Count){Assert-RuntimePreserved}
 'ROLLBACK_CODE_ONLY=True'
 'ROLLBACK_HEALTH=True AUTOMATION_DISABLED=True'
 'CURRENT_PID='+$started.id
}
# EXECUTE_TRANSITION
try {
 Assert-Admin
 $backend=[IO.Path]::GetFullPath($BackendPath).TrimEnd([char[]]@('\','/'))
 $stage=[IO.Path]::GetFullPath($StagePath).TrimEnd([char[]]@('\','/'))
 $backup=[IO.Path]::GetFullPath($BackupPath).TrimEnd([char[]]@('\','/'))
 foreach($path in @($backend,$stage,$backup)){Assert-PlainPath $path}
 $parent=Split-Path $backend -Parent
 foreach($path in @($stage,$backup)){
  if(![string]::Equals((Split-Path $path -Parent),$parent,[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($path,$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'PATH_INVALID'}
 }
 if(!(Get-Acl -LiteralPath $backup).AreAccessRulesProtected){throw 'BACKUP_NOT_PRIVATE'}
 $receipt=Get-Content -LiteralPath (Join-Path $backup 'backup-receipt.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if(!$receipt.rollbackCodeOnly -or ![string]::Equals($receipt.backend,$backend,[StringComparison]::OrdinalIgnoreCase) -or ![string]::Equals($receipt.stage,$stage,[StringComparison]::OrdinalIgnoreCase)){throw 'BACKUP_INVALID'}
 $codeRecord=$receipt.records | Where-Object {$_.label -ceq 'backend'} | Select-Object -First 1
 $runtimeRecords=@($receipt.records | Where-Object {$_.label -cin @('runtime-data','runtime-uploads')})
 if(!$codeRecord -or $runtimeRecords.Count -ne 2){throw 'BACKUP_INVALID'}
 $runtimeData=($runtimeRecords | Where-Object {$_.label -ceq 'runtime-data'}).source
 $runtimeUploads=($runtimeRecords | Where-Object {$_.label -ceq 'runtime-uploads'}).source
 foreach($r in $receipt.records) {if(!(Same-Snapshot $r.files (Snapshot (Join-Path $backup $r.label)))){throw 'BACKUP_CORRUPT'}}
 if((Get-FileHash -LiteralPath (Join-Path $backend '.env')).Hash -cne $receipt.envHash){throw 'ENV_CHANGED'}
 $journalFile=Join-Path $backup 'transition.json'
 if($Mode -ceq 'Rollback') {
  $journal=Get-Content -LiteralPath $journalFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if($journal.status -cne 'DEPLOYED' -or !$journal.currentPid -or ![string]::Equals($journal.work,(Split-Path $journal.oldCode -Parent),[StringComparison]::OrdinalIgnoreCase) -or
    !$journal.work.StartsWith($backup+'\transition-',[StringComparison]::OrdinalIgnoreCase)){throw 'JOURNAL_INVALID'}
  $ExpectedPid=[int]$journal.currentPid
  $v=Get-VerifiedProcess
  if([Math]::Abs(($v.process.CreationDate.ToUniversalTime()-[datetime]::Parse($journal.currentBirth).ToUniversalTime()).TotalMilliseconds) -gt 1){throw 'PID_CHANGED'}
  # Record today's runtime; never replace it with the earlier cutover snapshot.
  Stop-VerifiedBackend $v.process.CreationDate.ToUniversalTime().ToString('o')
  $stopped=$true
  $journal.currentPid=0;Save-Journal
  Recover-OldBackend
  'TRANSITION_RESULT=ROLLED_BACK'
 } else {
  if($ExpectedPid -ne $receipt.oldPid){throw 'PID_CHANGED'}
  Assert-Stage
  $v=Get-VerifiedProcess
  Assert-Birth $v $receipt.oldCreationDate
  if(![string]::Equals($v.process.ExecutablePath,$receipt.nodePath,[StringComparison]::OrdinalIgnoreCase)){throw 'NODE_CHANGED'}
  if(!(Same-Snapshot $codeRecord.files (Snapshot $backend @($runtimeRecords | ForEach-Object {$_.source})))){throw 'OLD_CODE_CHANGED'}
  Assert-Idle
  if($Mode -ceq 'Validate') {'TRANSITION_VALIDATED=True'}
  else {
   if(Test-Path -LiteralPath $journalFile){
    $previous=Get-Content -LiteralPath $journalFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if($previous.status -ceq 'PREPARED' -and !$previous.stopRequested -and !$previous.currentPid -and @($previous.parts).Count -eq 0){
     Move-Item -LiteralPath $journalFile -Destination (Join-Path $backup ('not-applied-'+[guid]::NewGuid().ToString('N')+'.json'))
    }else{throw 'TRANSITION_ALREADY_EXISTS'}
   }
   $work=Join-Path $backup ('transition-'+[guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path (Join-Path $work 'old-code') | Out-Null
   $journal=@{work=$work;oldCode=(Join-Path $work 'old-code');parts=@();status='PREPARED';stopRequested=$false;currentPid=0;currentBirth='';baseline=@()}
   Save-Journal
   'TRANSITION_PREFLIGHT=True'
   $phase='STOP_OLD'
   'TRANSITION_PHASE=STOP_OLD'
   Stop-VerifiedBackend $receipt.oldCreationDate
   $stopped=$true
   $phase='CUTOVER_BACKUP'
   'TRANSITION_PHASE=CUTOVER_BACKUP'
   Snapshot-QuiescedRuntime
   $phase='INSTALL_CODE'
   'TRANSITION_PHASE=INSTALL_CODE'
   Swap-Code
   Assert-RuntimePreserved
   $phase='START_NEW'
   'TRANSITION_PHASE=START_NEW'
   $started=Start-Backend
   $journal.currentPid=$started.id;$journal.currentBirth=$started.birth
   $ExpectedPid=$started.id
   Save-Journal
   $phase='READ_ONLY_SMOKE'
   'TRANSITION_PHASE=READ_ONLY_SMOKE'
   Assert-Health
   Assert-ReadOnlyApi
   Assert-RuntimePreserved
   $journal.status='DEPLOYED';Save-Journal
   'HEALTH=True API=True CONNECTION_RECORDS=True'
   'RUNTIME_PRESERVED=True ENV_PRESERVED=True'
   'AUTOMATION_DISABLED=True'
   'CURRENT_PID='+$started.id
   'TRANSITION_RESULT=DEPLOYED REVISION=162e259'
  }
 }
} catch {
 $reason=@('PATH_INVALID','BACKUP_NOT_PRIVATE','BACKUP_INVALID','BACKUP_CORRUPT','ENV_CHANGED','PID_CHANGED','NODE_CHANGED','STAGE_CHANGED','STAGE_DEPENDENCIES_MISSING','OLD_CODE_CHANGED','OPERATION_IN_PROGRESS','PUBLISH_IN_PROGRESS','ACTIVE_CONNECTIONS','PORT_BUSY','STOP_FAILED','CUTOVER_BACKUP_FAILED','INSTALLED_CODE_CHANGED','HEALTH_FAILED','AUTOMATION_NOT_DISABLED','TOKEN_PROBE_FAILED','API_CHECK_FAILED','CONNECTION_CHECK_FAILED','RECORD_CHECK_FAILED','RUNTIME_CHANGED','JOURNAL_INVALID','OLD_CODE_MISSING','ROLLBACK_CODE_CHECK_FAILED','TRANSITION_ALREADY_EXISTS','ADMIN_REQUIRED','REPARSE_PATH','COPY_FAILED','PROCESS_UNVERIFIED','BACKEND_PATH_MISMATCH','LAUNCH_UNVERIFIED')
 $code=if($reason -ccontains $_.Exception.Message){$_.Exception.Message}else{'TRANSITION_CHECK_FAILED'}
 'TRANSITION_FAILED=True PHASE='+$phase+' CODE='+$code
 if(($stopped -or ($journal -and $journal.stopRequested)) -and $journal) {
  try {Recover-OldBackend;'TRANSITION_RESULT=ROLLED_BACK'}
  catch {'TRANSITION_RESULT=RECOVERY_REQUIRED';'NO_RUNTIME_RESTORE_PERFORMED=True'}
 } else {'TRANSITION_RESULT=NOT_APPLIED'}
}
'TRANSITION_DONE'
