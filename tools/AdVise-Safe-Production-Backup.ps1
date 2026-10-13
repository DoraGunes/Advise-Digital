# Backup preparation only. No stop, restart, deploy, or Meta request.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$BackendPath,
 [Parameter(Mandatory=$true)][string]$StagePath,
 [int]$ExpectedPid=0
)
$ErrorActionPreference='Stop'
$phase='PRECHECK'
$backup=''
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
if(-not ('AdViseBackupProcess' -as [type])) {
 Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class AdViseBackupProcess {
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
   var current=new StringBuilder();string data="",uploads="";bool ended=false;
   // Read only within the target process. Retain only two runtime path settings.
   for(int i=0;i<65536;i++){
    char c=(char)BitConverter.ToUInt16(Read(h,env+2L*i,2),0);
    if(c=='\0'){
     if(current.Length==0){ended=true;break;}
     string row=current.ToString();current.Clear();
     if(row.StartsWith("ADVISE_DATA_DIR=",StringComparison.OrdinalIgnoreCase))data=row.Substring(16);
     if(row.StartsWith("ADVISE_UPLOAD_DIR=",StringComparison.OrdinalIgnoreCase))uploads=row.Substring(18);
    }else current.Append(c);
   }
   if(!ended)throw new Exception();
   return new string[]{cwd,data,uploads};
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
 $facts=[AdViseBackupProcess]::Facts($ExpectedPid)
 if(![string]::Equals($facts[0].TrimEnd([char[]]@('\','/')),$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'BACKEND_PATH_MISMATCH'}
 if($p.CommandLine -notmatch '(?i)(?:^|[\s"''])src[\\/]server\.js(?:$|[\s"''])' -and
    $p.CommandLine.IndexOf((Join-Path $backend 'src\server.js'),[StringComparison]::OrdinalIgnoreCase) -lt 0 -and
    $p.CommandLine.IndexOf(($backend.Replace('\','/')+'/src/server.js'),[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'LAUNCH_UNVERIFIED'}
 return @{process=$p;facts=$facts}
}
try {
 $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if(!$admin){throw 'ADMIN_REQUIRED'}
 $backend=[IO.Path]::GetFullPath($BackendPath).TrimEnd([char[]]@('\','/'))
 $stage=[IO.Path]::GetFullPath($StagePath).TrimEnd([char[]]@('\','/'))
 Assert-PlainPath $backend
 Assert-PlainPath $stage
 if(![string]::Equals((Split-Path $stage -Parent),(Split-Path $backend -Parent),[StringComparison]::OrdinalIgnoreCase)){throw 'STAGE_PATH_INVALID'}
 $manifest=Get-Content -LiteralPath (Join-Path $stage 'stage.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if($manifest.revision -cne 'cb6a908426c80752936d6cab40a0c645f641d4ea' -or !$manifest.stagingOnly -or
    ![string]::Equals($manifest.backend,$backend,[StringComparison]::OrdinalIgnoreCase)){throw 'STAGE_MANIFEST_INVALID'}
 $original=Get-VerifiedProcess
 $creation=$original.process.CreationDate.ToUniversalTime().ToString('o')
 $envFile=Join-Path $backend '.env'
 Assert-PlainPath $envFile
 $envHash=(Get-FileHash -LiteralPath $envFile -Algorithm SHA256).Hash
 if($envHash -cne $manifest.envHash){throw 'ENV_CHANGED_SINCE_STAGE'}
 $parent=Split-Path $backend -Parent
 $backup=Join-Path $parent ('_advise-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $backup | Out-Null
 Protect-Directory $backup
 'BACKUP_PRIVATE_ACL=True'
 $data=$original.facts[1];$uploads=$original.facts[2]
 if(!$data){$data=Join-Path $backend 'data'}
 if(!$uploads){$uploads=Join-Path $backend 'uploads'}
 $runtime=@()
 foreach($row in @(@{label='runtime-data';path=$data},@{label='runtime-uploads';path=$uploads})) {
  $resolved=if([IO.Path]::IsPathRooted($row.path)){[IO.Path]::GetFullPath($row.path)}else{[IO.Path]::GetFullPath((Join-Path $backend $row.path))}
  $resolved=$resolved.TrimEnd([char[]]@('\','/'))
  if(!(Test-Path -LiteralPath $resolved -PathType Container)){throw 'RUNTIME_PATH_UNVERIFIED'}
  Assert-PlainPath $resolved
  if([string]::Equals($resolved,$backend,[StringComparison]::OrdinalIgnoreCase) -or
     $backend.StartsWith($resolved+'\',[StringComparison]::OrdinalIgnoreCase) -or
     $backup.StartsWith($resolved+'\',[StringComparison]::OrdinalIgnoreCase) -or
     $stage.StartsWith($resolved+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'RUNTIME_PATH_UNVERIFIED'}
  $runtime+=@{label=$row.label;path=$resolved;exclude=@()}
 }
 $sources=@(@{label='backend';path=$backend;exclude=@($runtime | ForEach-Object {$_.path})})+$runtime
 $phase='SNAPSHOT'
 $records=@()
 foreach($source in $sources) {
  $destination=Join-Path $backup $source.label
  'BACKUP_SECTION='+$source.label
  $stable=$false
  for($attempt=1;$attempt -le 3;$attempt++) {
   $before=Snapshot $source.path $source.exclude
   Copy-Tree $source.path $destination (Join-Path $backup ($source.label+'-copy-local.log')) $source.exclude
   $after=Snapshot $source.path $source.exclude
   $copied=Snapshot $destination
   if((Same-Snapshot $before $after) -and (Same-Snapshot $after $copied)){$stable=$true;break}
  }
  if(!$stable){throw 'SOURCE_CHANGED_DURING_BACKUP'}
  $records+=@{label=$source.label;source=$source.path;files=$copied}
 }
 # Capture launcher/proxy/config files immediately beside backend, without copying staging.
 $configs=Join-Path $backup 'root-config'
 New-Item -ItemType Directory -Path $configs | Out-Null
 foreach($file in Get-ChildItem -LiteralPath $parent -Force -File | Where-Object {$_.Extension -match '^\.(bat|cmd|ps1|json|yaml|yml|toml|ini|config|conf|pem|crt|key|pfx)$' -or $_.Name -ceq 'Caddyfile' -or $_.Name -ceq 'ecosystem.config.js' -or $_.Name -ceq '.npmrc' -or $_.Name -cmatch '^\.env(?:\..+)?$'}) {
  Assert-PlainPath $file.FullName
  $target=Join-Path $configs $file.Name
  Copy-Item -LiteralPath $file.FullName -Destination $target
  if((Get-FileHash -LiteralPath $file.FullName).Hash -cne (Get-FileHash -LiteralPath $target).Hash){throw 'CONFIG_COPY_FAILED'}
 }
 $records+=@{label='root-config';source=$parent;files=(Snapshot $configs)}
 $phase='RESTORE_PROBE'
 $probe=Join-Path $backup 'restore-probe'
 foreach($record in $records) {
  $copy=Join-Path $probe $record.label
  Copy-Tree (Join-Path $backup $record.label) $copy (Join-Path $backup ($record.label+'-restore-local.log'))
  if(!(Same-Snapshot $record.files (Snapshot $copy))){throw 'RESTORE_PROBE_FAILED'}
 }
 $phase='FINAL_PROCESS_CHECK'
 $final=Get-VerifiedProcess
 if($final.process.CreationDate.ToUniversalTime().ToString('o') -cne $creation){throw 'PID_CHANGED'}
 if((Get-FileHash -LiteralPath $envFile -Algorithm SHA256).Hash -cne $envHash){throw 'ENV_CHANGED_DURING_BACKUP'}
 $receipt=@{backend=$backend;stage=$stage;oldPid=$ExpectedPid;oldCreationDate=$creation;nodePath=$original.process.ExecutablePath;envHash=$envHash;dataPath=$data;uploadPath=$uploads;records=$records;rollbackCodeOnly=$true;runningSnapshot=$true}
 $receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $backup 'backup-receipt.json') -Encoding UTF8
 'BACKUP_INTEGRITY=True'
 'RESTORE_PROBE=True'
 'PROCESS_RECHECK=True PID='+$ExpectedPid
 'BACKUP_PATH='+$backup
 'BACKUP_READY=True'
} catch {
 $allowed=@('REPARSE_PATH','COPY_FAILED','PRIVATE_BACKUP_ACL_FAILED','PID_CHANGED','PROCESS_UNVERIFIED','BACKEND_PATH_MISMATCH','LAUNCH_UNVERIFIED','ADMIN_REQUIRED','STAGE_PATH_INVALID','STAGE_MANIFEST_INVALID','ENV_CHANGED_SINCE_STAGE','RUNTIME_PATH_UNVERIFIED','SOURCE_CHANGED_DURING_BACKUP','CONFIG_COPY_FAILED','RESTORE_PROBE_FAILED','ENV_CHANGED_DURING_BACKUP')
 $reason=if($allowed -ccontains $_.Exception.Message){$_.Exception.Message}else{'BACKUP_CHECK_FAILED'}
 'BACKUP_READY=False REASON='+$reason+' PHASE='+$phase
 if($backup){'INCOMPLETE_BACKUP_PATH='+$backup}
}
'BACKUP_ONLY_DONE'
