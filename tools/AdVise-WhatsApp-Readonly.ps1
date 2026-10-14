[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$BackendPath,
 [Parameter(Mandatory=$true)][string]$BackupPath,
 [int]$ExpectedPid=21372
)
$ErrorActionPreference='Stop'
try {
 $definition=(Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/DoraGunes/Advise-Digital/b0d8dbe94b9e949e47a1d6e57e809b8c154db17b/tools/AdVise-Safe-Production-Transition.ps1').Content
 $cut=$definition.IndexOf('# EXECUTE_TRANSITION')
 if($cut -lt 1){throw 'SCRIPT_INVALID'}
 . ([scriptblock]::Create($definition.Substring(0,$cut))) -BackendPath $BackendPath -StagePath $BackendPath -BackupPath $BackupPath -ExpectedPid $ExpectedPid
 $backend=[IO.Path]::GetFullPath($BackendPath).TrimEnd([char[]]@('\','/'))
 Assert-Admin
 $verified=Get-VerifiedProcess
 if($verified.facts[3] -cne 'false'){throw 'AUTOMATION_ENABLED'}
 $receipt=Get-Content -LiteralPath (Join-Path $BackupPath 'backup-receipt.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 $journal=Get-Content -LiteralPath (Join-Path $BackupPath 'transition.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if($journal.currentPid -ne $ExpectedPid -or
    [Math]::Abs(($verified.process.CreationDate.ToUniversalTime()-[datetime]::Parse($journal.currentBirth).ToUniversalTime()).TotalMilliseconds) -gt 1 -or
    ![string]::Equals($receipt.nodePath,$verified.process.ExecutablePath,[StringComparison]::OrdinalIgnoreCase)){throw 'PROCESS_CHANGED'}
 $data=($receipt.records | Where-Object {$_.label -ceq 'runtime-data'}).source
 $js=@'
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
process.env.DOTENV_CONFIG_QUIET='true';
const meta=await import(pathToFileURL(path.join(process.cwd(),'src/meta.js')).href);
const {config}=await import(pathToFileURL(path.join(process.cwd(),'src/config.js')).href);
const tenant=JSON.parse(fs.readFileSync(path.join(process.argv[1],'tenants.json'),'utf8')).find(row=>row.id==='system');
if(!tenant?.meta?.connected)throw Error('Connection not present');
const c=meta.resolveCredentials({...tenant.meta,systemAccount:false});
if(!/^\d+$/.test(c.pageId)||!/^v\d+\.\d+$/.test(config.metaApiVersion))throw Error('Invalid identity');
console.log('WA_CONFIG wabaPresent='+Boolean(c.metaWhatsappWabaId)+' phoneIdPresent='+Boolean(c.metaWhatsappPhoneNumberId));
const flag=value=>value===true?'TRUE':value===false?'FALSE':'UNKNOWN';
async function get(resource,fields){
 const url=new URL('https://graph.facebook.com/'+config.metaApiVersion+'/'+resource);
 if(fields)url.searchParams.set('fields',fields);
 const r=await fetch(url,{method:'GET',headers:{Authorization:'Bearer '+c.accessToken},redirect:'error',signal:AbortSignal.timeout(20000)});
 const data=await r.json();
 return {ok:r.ok&&!data.error,status:r.status,data,code:Number(data.error?.code)||0,subcode:Number(data.error?.error_subcode)||0};
}
const page=await get(c.pageId,'id,has_whatsapp_business_number,has_whatsapp_number');
console.log('WA_PAGE ok='+page.ok+' business='+flag(page.data.has_whatsapp_business_number)+' number='+flag(page.data.has_whatsapp_number)+' http='+page.status+' code='+page.code+' subcode='+page.subcode);
const permissions=await get('me/permissions');
const granted=new Set((permissions.data.data||[]).filter(row=>row.status==='granted').map(row=>row.permission));
console.log('WA_PERMISSIONS ok='+permissions.ok+' ads='+granted.has('ads_management')+' page='+granted.has('pages_read_engagement')+' management='+granted.has('whatsapp_business_management')+' messaging='+granted.has('whatsapp_business_messaging'));
try{
 await meta.validateRadiusTargeting({latitude:40.7356,longitude:31.6061,radius:200,distance_unit:'kilometer'},c);
 console.log('RADIUS_ONLY accepted=True radiusKm=200 whatsappNotEvaluated=True');
}catch(error){
 const cause=error.cause||error;
 console.log('RADIUS_ONLY accepted=False radiusKm=200 http='+(Number(cause.status)||0)+' code='+(Number(cause.providerCode)||0)+' subcode='+(Number(cause.providerSubcode)||0)+' whatsappNotEvaluated=True');
}
'@
 'PROCESS_VERIFIED=True AUTOMATION_DISABLED=True'
 Push-Location $backend
 try {
  $output=@(& $receipt.nodePath --input-type=module -e $js $data 2>$null)
  $exitCode=$LASTEXITCODE
  $output | Where-Object {$_ -cmatch '^(WA_CONFIG |WA_PAGE |WA_PERMISSIONS |RADIUS_ONLY )'}
  if($exitCode -ne 0){'WA_DIAGNOSTIC_FAILED=True'}
 }finally{Pop-Location}
}catch{'WA_DIAGNOSTIC_STOPPED=True'}
'READ_ONLY_DONE'
