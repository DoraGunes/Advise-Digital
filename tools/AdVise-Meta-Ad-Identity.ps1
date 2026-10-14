[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$BackendPath,
 [Parameter(Mandatory=$true)][string]$BackupPath,
 [int]$ExpectedPid=21372,
 [Parameter(Mandatory=$true)][ValidatePattern('^\d{1,30}$')][string]$AdId,
 [Parameter(Mandatory=$true)][ValidatePattern('^\d{1,30}$')][string]$AlternativeAccountId
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

// BEGIN_IDENTITY_READER
async function inspectAdIdentity({apiVersion,token,currentAccountId,alternativeAccountId,adId,expectedPageId,fetcher=fetch,emit=console.log}){
 const cleanId=value=>/^\d{1,30}$/.test(String(value||''))?String(value):'';
 if(!/^v\d+\.\d+$/.test(apiVersion)||![currentAccountId,alternativeAccountId,adId,expectedPageId].every(cleanId))throw Error('Invalid identity');
 const allowedAccounts=new Set([currentAccountId,alternativeAccountId]);
 async function get(resource,fields,extra={}){
  const url=new URL('https://graph.facebook.com/'+apiVersion+'/'+resource);
  url.searchParams.set('fields',fields);
  for(const [key,value]of Object.entries(extra))url.searchParams.set(key,String(value));
  try{
   const response=await fetcher(url,{method:'GET',headers:{Authorization:'Bearer '+token},redirect:'error',signal:AbortSignal.timeout(20000)});
   const data=await response.json();
   return {ok:response.ok&&!data.error,status:response.status,data,code:Number(data.error?.code)||0,subcode:Number(data.error?.error_subcode)||0};
  }catch{return {ok:false,status:0,data:{},code:0,subcode:0};}
 }
 const safe=value=>/^[A-Z_]{1,60}$/.test(String(value||''))?String(value):'UNKNOWN';
 const phoneFields=value=>Object.keys(value||{}).filter(key=>['whatsapp_number_id','whats_app_business_phone_number_id','whatsapp_phone_number'].includes(key)).join(',')||'NONE';
 function reportSet(row,label){
  const promoted=row.promoted_object||{};
  emit(label+' id='+(cleanId(row.id)||'UNKNOWN')+' account='+(cleanId(row.account_id)||'UNKNOWN')
   +' destination='+safe(row.destination_type)+' optimization='+safe(row.optimization_goal)+' billing='+safe(row.billing_event)
   +' pageExpected='+(cleanId(promoted.page_id)===expectedPageId)+' phoneFields='+phoneFields(promoted));
 }
 emit('GRAPH_VERSION value='+apiVersion);
 const accounts=new Map();
 for(const account of allowedAccounts){
  const r=await get('act_'+account,'id,account_id,account_status,currency');
  const verified=r.ok&&cleanId(r.data.account_id)===account;
  accounts.set(account,verified);
  emit('ACCOUNT_ACCESS account='+account+' verified='+verified+' http='+r.status+' code='+r.code+' subcode='+r.subcode);
 }
 const ad=await get(adId,'id,account_id,campaign_id,adset_id,creative{id}');
 emit('AD_LOOKUP requested='+adId+' ok='+ad.ok+' http='+ad.status+' code='+ad.code+' subcode='+ad.subcode);
 if(ad.ok){
  const row=ad.data,account=cleanId(row.account_id);
  const campaign=cleanId(row.campaign_id),set=cleanId(row.adset_id),creative=cleanId(row.creative?.id);
  emit('AD_IDENTITY ad='+(cleanId(row.id)||'UNKNOWN')+' account='+(account||'UNKNOWN')
   +' campaign='+(campaign||'UNKNOWN')+' set='+(set||'UNKNOWN')+' creative='+(creative||'UNKNOWN')
   +' currentAccount='+(account===currentAccountId)+' hierarchyIdsEqual='+(adId===set&&set===campaign));
  if(cleanId(row.id)===adId&&allowedAccounts.has(account)&&accounts.get(account)){
   if(set){
    const r=await get(set,'id,account_id,campaign_id,destination_type,optimization_goal,billing_event,promoted_object');
    if(r.ok&&cleanId(r.data.id)===set&&cleanId(r.data.account_id)===account)reportSet(r.data,'ADSET_DETAILS');
    else emit('ADSET_DETAILS verified=False http='+r.status+' code='+r.code+' subcode='+r.subcode);
   }
   if(creative){
    const r=await get(creative,'id,account_id,call_to_action_type,call_to_action,object_story_spec,source_instagram_media_id');
    if(r.ok&&cleanId(r.data.id)===creative&&cleanId(r.data.account_id)===account){
     const story=r.data.object_story_spec||{};
     const cta=r.data.call_to_action||story.link_data?.call_to_action||story.video_data?.call_to_action||{};
     emit('CREATIVE_DETAILS verified=True cta='+safe(r.data.call_to_action_type||cta.type)
      +' whatsappDestination='+(cta.value?.app_destination==='WHATSAPP')
      +' pageExpected='+(cleanId(story.page_id)===expectedPageId)
      +' existingInstagramMedia='+Boolean(r.data.source_instagram_media_id));
    }else emit('CREATIVE_DETAILS verified=False http='+r.status+' code='+r.code+' subcode='+r.subcode);
   }
  }else emit('RELATED_READS skipped=True reason=ACCOUNT_NOT_VERIFIED');
 }else{
  const type=await get(adId,'id',{metadata:'1'});
  const kind=['Ad','AdSet','Campaign','Page','User','InstagramMedia','PagePost'].includes(type.data.metadata?.type)?type.data.metadata.type:'UNKNOWN';
  emit('AD_OBJECT_TYPE readable='+type.ok+' type='+kind+' http='+type.status+' code='+type.code);
 }
 // A bounded look at current-account ads can expose actual IDs even if the AI candidate is invalid.
 if(accounts.get(currentAccountId)){
  const r=await get('act_'+currentAccountId+'/ads','id,campaign_id,adset_id,adset{destination_type,promoted_object}',{limit:20});
  if(r.ok&&Array.isArray(r.data.data)){
   emit('CURRENT_ADS count='+r.data.data.length+' hasMore='+Boolean(r.data.paging?.next));
   for(const row of r.data.data){
    const promoted=row.adset?.promoted_object||{};
    emit('CURRENT_AD ad='+(cleanId(row.id)||'UNKNOWN')+' set='+(cleanId(row.adset_id)||'UNKNOWN')
     +' campaign='+(cleanId(row.campaign_id)||'UNKNOWN')+' whatsapp='+(row.adset?.destination_type==='WHATSAPP')
     +' pageExpected='+(cleanId(promoted.page_id)===expectedPageId)+' phoneFields='+phoneFields(promoted));
   }
  }else emit('CURRENT_ADS verified=False http='+r.status+' code='+r.code+' subcode='+r.subcode);
 }
}
// END_IDENTITY_READER

await inspectAdIdentity({apiVersion:config.metaApiVersion,token:c.accessToken,currentAccountId:c.adAccountId,alternativeAccountId:process.argv[3],adId:process.argv[2],expectedPageId:c.pageId});
'@
 'PROCESS_VERIFIED=True AUTOMATION_DISABLED=True'
 Push-Location $backend
 try {
  $output=@(& $receipt.nodePath --input-type=module -e $js $data $AdId $AlternativeAccountId 2>$null)
  $exitCode=$LASTEXITCODE
  $output | Where-Object {$_ -cmatch '^(GRAPH_VERSION |ACCOUNT_ACCESS |AD_LOOKUP |AD_IDENTITY |ADSET_DETAILS |CREATIVE_DETAILS |RELATED_READS |AD_OBJECT_TYPE |CURRENT_ADS |CURRENT_AD )'}
  if($exitCode -ne 0){'IDENTITY_DIAGNOSTIC_FAILED=True'}
 }finally{Pop-Location}
}catch{'IDENTITY_DIAGNOSTIC_STOPPED=True'}
'READ_ONLY_DONE'
