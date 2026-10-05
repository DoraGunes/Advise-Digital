import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomUUID,createHash} from 'node:crypto';
import {AsyncLocalStorage} from 'node:async_hooks';

export const dataRoot = path.resolve(process.env.ADVISE_DATA_DIR || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data'));
const context = new AsyncLocalStorage();
let queue = Promise.resolve();
const lockPath = path.join(dataRoot, '.advise-write-lock');

// Shared by HTTP writes and cron: reentrant in one process, exclusive across processes.
export async function withDataLock(task) {
  if (context.getStore()) return task();
  const run = queue.then(async () => {
    await fs.mkdir(dataRoot, {recursive:true});
    const deadline = Date.now() + 180000;
    while (true) {
      try {
        await fs.mkdir(lockPath);
        await fs.writeFile(path.join(lockPath, 'owner.json'), JSON.stringify({pid:process.pid,at:Date.now()}));
        break;
      } catch (error) {
        if (error.code !== 'EEXIST') throw error;
        let stale = false;
        try {
          const owner = JSON.parse(await fs.readFile(path.join(lockPath,'owner.json'),'utf8'));
          try { process.kill(owner.pid,0); } catch (probe) { stale = probe.code === 'ESRCH'; }
        } catch { const info=await fs.stat(lockPath).catch(()=>null); stale=info && Date.now()-info.mtimeMs>180000; }
        if (stale) { await fs.rm(lockPath,{recursive:true,force:true}); continue; }
        if (Date.now() > deadline) throw new Error('Başka bir işlem devam ediyor. Lütfen biraz sonra tekrar deneyin.');
        await new Promise(resolve=>setTimeout(resolve,50));
      }
    }
    try { return await context.run(true,task); }
    finally { await fs.rm(lockPath,{recursive:true,force:true}); }
  }, async () => withDataLock(task));
  queue = run.catch(()=>{});
  return run;
}

const tenantContext = new AsyncLocalStorage();
const tenantQueues = new Map();

function tenantLockPath(tenantId) {
  const key=String(tenantId||'system');
  const hash=createHash('sha256').update(key).digest('hex').slice(0,24);
  return path.join(dataRoot,`.advise-tenant-lock-${hash}`);
}

async function acquireTenantFileLock(lockDir) {
  await fs.mkdir(dataRoot,{recursive:true});
  const deadline=Date.now()+600000;
  while(true) {
    try {
      await fs.mkdir(lockDir);
      await fs.writeFile(path.join(lockDir,'owner.json'),JSON.stringify({pid:process.pid,at:Date.now()}));
      return;
    } catch(error) {
      if(error.code!=='EEXIST')throw error;
      let stale=false;
      try {
        const owner=JSON.parse(await fs.readFile(path.join(lockDir,'owner.json'),'utf8'));
        try { process.kill(owner.pid,0); }
        catch(probe) { stale=probe.code==='ESRCH'; }
      } catch {
        const info=await fs.stat(lockDir).catch(()=>null);
        stale=Boolean(info&&Date.now()-info.mtimeMs>600000);
      }
      if(stale) {
        await fs.rm(lockDir,{recursive:true,force:true});
        continue;
      }
      if(Date.now()>deadline)throw new Error('Bu hesapta başka bir işlem devam ediyor. Lütfen biraz sonra tekrar deneyin.');
      await new Promise(resolve=>setTimeout(resolve,50));
    }
  }
}

export async function withTenantLock(tenantId,task) {
  const key=String(tenantId||'system');
  const held=tenantContext.getStore();
  if(held?.has(key))return task();

  const previous=tenantQueues.get(key)||Promise.resolve();
  let releaseTurn=()=>{};
  const gate=new Promise(resolve=>{releaseTurn=resolve;});
  const turn=previous.catch(()=>{}).then(()=>gate);
  tenantQueues.set(key,turn);
  await previous.catch(()=>{});

  const lockDir=tenantLockPath(key);
  let fileLocked=false;
  try {
    await acquireTenantFileLock(lockDir);
    fileLocked=true;
    const nextHeld=new Set(held||[]);
    nextHeld.add(key);
    return await tenantContext.run(nextHeld,task);
  } finally {
    if(fileLocked)await fs.rm(lockDir,{recursive:true,force:true}).catch(()=>{});
    releaseTurn();
    if(tenantQueues.get(key)===turn)tenantQueues.delete(key);
  }
}

export async function readJsonFile(file,fallback) {
  try { return JSON.parse(await fs.readFile(file,'utf8')); }
  catch (error) {
    if (error.code === 'ENOENT') return structuredClone(fallback);
    throw new Error(`Kayıt dosyası okunamadı (${path.basename(file)}). Mevcut veri korunmuştur.`);
  }
}

export async function writeJsonFile(file,value) {
  return withDataLock(async()=>{
    await fs.mkdir(path.dirname(file),{recursive:true});
    const temp=`${file}.${process.pid}.${randomUUID()}.tmp`;
    try { await fs.writeFile(temp,JSON.stringify(value,null,2),'utf8'); await fs.rename(temp,file); }
    finally { await fs.rm(temp,{force:true}).catch(()=>{}); }
  });
}
