import {AsyncLocalStorage} from 'node:async_hooks';

const deadlines = new AsyncLocalStorage();
export function timeoutError(stage='provider') {
  return Object.assign(new Error('İşlem zaman aşımına uğradı.'), {code:'ETIMEDOUT',stage});
}
export function remainingMs(maximum=30000) {
  const deadline=deadlines.getStore();
  const remaining=deadline===undefined?maximum:Math.min(maximum,deadline-Date.now());
  if(remaining<=0)throw timeoutError();
  return remaining;
}
export function withOperationBudget(milliseconds, task) {
  const parent=deadlines.getStore();
  const deadline=Math.min(parent??Infinity,Date.now()+milliseconds);
  return deadlines.run(deadline,task);
}
// Used for read-only tasks or cancellable provider requests. Financial writes
// retain their lock until the transport settles; never race a write handler.
export async function boundedRead(task,milliseconds,stage='provider') {
  let timer;
  const controller=new AbortController();
  try {
    return await Promise.race([
      Promise.resolve().then(()=>task(controller.signal)),
      new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(timeoutError(stage));},milliseconds);})
    ]);
  } finally {clearTimeout(timer);}
}
