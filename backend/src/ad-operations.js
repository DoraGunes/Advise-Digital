import path from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {dataRoot,readJsonFile,writeJsonFile,withDataLock,withTenantLock} from './persistence.js';

const file=path.join(dataRoot,'ad_operations.json');
export function operationFailure(error,stage,correlationId) {
  const code=/^[A-Z_]{3,60}$/.test(String(error?.code||''))?error.code:'AD_CREATE_FAILED';
  const messages={ETIMEDOUT:'Meta yanıtı zamanında tamamlanamadı.',OPERATION_BUSY:'Bu hesapta başka bir işlem devam ediyor. Biraz sonra yeniden deneyin.',AD_RECONCILE_REQUIRED:'Meta sonucu belirsiz. Yeni reklam oluşturmadan önce işlem kimliğiyle Meta kayıtlarını kontrol edin.',IDEMPOTENCY_CONFLICT:'Bu işlem kimliği farklı bir reklam isteğinde kullanılmış. Önce mevcut işlemi kontrol edin.'};
  // Only controlled Turkish errors are displayed; upstream payloads are never reflected.
  const raw=String(error?.message||'');
  const safe=raw.length<=220&&!/[{}<>\r\n]|https?:|token|secret|bearer|api.?key/i.test(raw)&&/[çğıöşüÇĞİÖŞÜ]/.test(raw);
  const reason=messages[code]||(safe?raw:'Reklam isteği tamamlanamadı. Bağlantı ve hesap ayarlarını kontrol edin.');
  return {ok:false,code,stage,retryable:error?.retryable===true,userMessage:`${reason} (Adım: ${stage})`,error:reason,correlationId};
}
export async function getAdOperation(tenantId,key) {
  const rows=await readJsonFile(file,[]);
  return rows.find(row=>row.tenantId===tenantId&&row.requestId===key)||null;
}
async function save(operation) {
  return withDataLock(async()=>{
    const rows=await readJsonFile(file,[]);
    const index=rows.findIndex(row=>row.tenantId===operation.tenantId&&row.requestId===operation.requestId);
    const value={...operation,updatedAt:new Date().toISOString()};
    if(index<0)rows.push(value);else rows[index]=value;
    await writeJsonFile(file,rows);
  });
}
// The caller supplies ordered provider actions. Save STARTED before each remote
// write and its ID before moving on. A crash/ambiguous transport never replays it.
export async function runAdOperation({tenantId,requestId,payload,prepare,steps,complete}) {
  if(!/^[a-zA-Z0-9_-]{16,100}$/.test(requestId||''))throw Object.assign(new Error('Geçerli reklam işlem kimliği gerekli. Uygulamayı güncelleyip yeniden deneyin.'),{code:'REQUEST_ID_REQUIRED'});
  return withTenantLock(tenantId,async()=>{
    const fingerprint=createHash('sha256').update(JSON.stringify(payload)).digest('hex');
    let operation=await getAdOperation(tenantId,requestId);
    if(operation&&operation.fingerprint!==fingerprint)throw Object.assign(new Error('İstek kimliği farklı içerikte kullanılmış.'),{code:'IDEMPOTENCY_CONFLICT'});
    if(operation?.status==='SUCCEEDED')return operation.result;
    if(operation?.status==='RECONCILE'||operation?.status==='RUNNING'&&operation?.startedStage)throw Object.assign(new Error('Meta sonucunu kontrol edin.'),{code:'AD_RECONCILE_REQUIRED'});
    operation??={tenantId,requestId,fingerprint,correlationId:randomUUID(),status:'RUNNING',stage:'preflight',ids:{},createdAt:new Date().toISOString()};
    let writing=false;
    try {
      operation.status='RUNNING';operation.stage='preflight';await save(operation);
      const context=await prepare(operation);
      for(const [stage,action] of steps) {
        if(operation.ids[stage])continue;
        operation.stage=stage;operation.startedStage=stage;await save(operation);writing=true;
        const result=await action(operation.ids,context);
        if(!result?.id)throw Object.assign(new Error('Meta oluşturulan reklam kimliğini doğrulamadı.'),{code:'AD_RECONCILE_REQUIRED'});
        operation.ids[stage]=String(result.id);operation.startedStage=null;writing=false;await save(operation);
      }
      operation.stage='completion';
      operation.result=await complete(operation,context);
      operation.status='SUCCEEDED';await save(operation);
      return operation.result;
    } catch(error) {
      const ambiguous=writing&&(operation.stage==='activation'||!Number.isInteger(error.status)||error.status>=500)||error.code==='AD_RECONCILE_REQUIRED';
      operation.status=ambiguous?'RECONCILE':Object.keys(operation.ids).length?'PARTIAL_FAILED':'FAILED';
      if(!ambiguous)operation.startedStage=null;
      operation.failure=operationFailure(ambiguous?Object.assign(new Error('Meta sonucu belirsiz.'),{code:'AD_RECONCILE_REQUIRED'}):error,operation.stage,operation.correlationId);
      operation.providerFailure={status:Number(error.status)||null,code:Number(error.providerCode)||null,subcode:Number(error.providerSubcode)||null,trace:error.providerTrace||null};
      await save(operation);
      throw Object.assign(new Error(operation.failure.userMessage),{failure:operation.failure,status:error.status});
    }
  });
}
