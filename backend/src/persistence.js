import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
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
