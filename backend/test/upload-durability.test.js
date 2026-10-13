import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-upload-durability-'));
Object.assign(process.env,{
  DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),
  ADVISE_DATA_DIR:fixture,ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  ADVISE_NO_LISTEN:'true',CRON_ENABLED:'false',
  JWT_SECRET:'fixture-only-session-secret',ADMIN_USERNAME:'fixture-admin',
  ADMIN_PASSWORD:'fixture-password',GEMINI_API_KEY:'',GOOGLE_API_KEY:'',
  META_ACCESS_TOKEN:'',INSTAGRAM_ACCESS_TOKEN:''
});
after(async()=>{assert.ok(fixture.startsWith(os.tmpdir()));await fs.rm(fixture,{recursive:true,force:true});});

test('single and bulk upload retain committed JPEG media and return success when audit logging fails',async()=>{
  const sharp=(await import('sharp')).default;
  const store=await import('../src/store.js'),auth=await import('../src/auth.js');
  const tenant=await store.createTenant({companyName:'Upload durability fixture',plan:'AGENCY'});
  await store.saveSettings(tenant.id,{autoPublish:false,aiEnabled:false});
  await auth.createTenantUser({tenantId:tenant.id,username:'fixture-upload-manager',password:'fixture-password',role:'MANAGER'});
  const session=await auth.login('fixture-upload-manager','fixture-password');
  const {app}=await import('../src/server.js');
  const listener=app.listen(0,'127.0.0.1');
  await new Promise(resolve=>listener.once('listening',resolve));
  const base='http://127.0.0.1:'+listener.address().port;
  // A directory at the log file path deterministically causes getLogs/addLog to fail.
  await fs.rm(path.join(fixture,'logs.json'),{force:true});
  await fs.mkdir(path.join(fixture,'logs.json'));
  try {
    for(const [route,field,colour] of [['/api/posts','image','#123456'],['/api/posts/bulk','files','#abcdef']]) {
      const png=await sharp({create:{width:32,height:48,channels:4,background:colour}}).png().toBuffer();
      const form=new FormData();
      form.append(field,new Blob([png],{type:'image/png'}),'fixture.png');
      form.append('useAI','false');form.append('autoPublish','false');
      const response=await fetch(base+route,{method:'POST',headers:{authorization:'Bearer '+session.token},body:form});
      const body=await response.json();
      assert.equal(response.status,201,JSON.stringify(body));
      const post=body.posts?body.posts[0]:body;
      const saved=(await store.getPosts(tenant.id)).find(row=>row.id===post.id);
      assert.ok(saved,'successful response must have a durable post');
      assert.equal(saved.publishStatus,'MANUAL');
      assert.equal(saved.mimeType,'image/jpeg');
      assert.equal((await sharp(await fs.readFile(saved.filePath)).metadata()).format,'jpeg');
    }
    assert.equal((await store.getPosts(tenant.id)).length,2);
  } finally {
    listener.closeAllConnections();
    await new Promise(resolve=>listener.close(resolve));
  }
});
