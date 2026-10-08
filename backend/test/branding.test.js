import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
const root=new URL('../../mobile/',import.meta.url);
const read=relative=>fs.readFile(new URL(relative,root));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const textHash=text=>createHash('sha256').update(text.replace(/\r\n/g,'\n')).digest('hex');
test('canonical logo/icon source hashes and actual PNG encoding are preserved',async()=>{
  const canonical=JSON.parse(await read('assets/branding/canonical.json'));
  for(const [name,key]of [['advise_app_icon','appIcon'],['advise_full_logo','fullLogo']]) {
    const jpeg=await read(`assets/branding/${name}.jpeg`),png=await read(`assets/branding/${name}.png`);
    assert.equal(hash(jpeg),canonical[key].sha256);assert.equal((await sharp(jpeg).metadata()).format,'jpeg');
    assert.equal((await sharp(png).metadata()).format,'png');
  }
  const full=await sharp(await read('assets/branding/advise_full_logo.png')).metadata();
  assert.equal(full.width/canonical.fullLogo.width,full.height/canonical.fullLogo.height);
  assert.equal(hash(await read('assets/advise_logo.jpg')),canonical.fullLogo.sha256);
});
test('Android/PWA/favicon icons are real PNGs with correct dimensions and manifest identity unchanged',async()=>{
  for(const [density,size]of [['mdpi',48],['hdpi',72],['xhdpi',96],['xxhdpi',144],['xxxhdpi',192]])for(const name of ['ic_launcher','ic_launcher_round']) {
    const metadata=await sharp(await read(`android/app/src/main/res/mipmap-${density}/${name}.png`)).metadata();assert.equal(metadata.format,'png');assert.equal(metadata.width,size);assert.equal(metadata.height,size);
  }
  for(const size of [192,512])for(const kind of ['Icon','Icon-maskable']){const metadata=await sharp(await read(`web/icons/${kind}-${size}.png`)).metadata();assert.equal(metadata.width,size);assert.equal(metadata.height,size);assert.equal(metadata.format,'png');}
  assert.equal((await sharp(await read('web/favicon.png')).metadata()).width,32);
  const adaptive=await read('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');assert.match(adaptive.toString(),/advise_app_icon_foreground/);
  const bytes=await read('web/manifest.json'),manifest=JSON.parse(bytes),canonical=JSON.parse(await read('assets/branding/canonical.json'));
  assert.equal(textHash(bytes.toString('utf8')),canonical.manifestSha256);assert.equal(manifest.id,'.');assert.equal(manifest.start_url,'.');assert.equal(manifest.scope,undefined);
});
test('Windows ICO has six valid PNG frames and correct offsets',async()=>{
  const ico=await read('windows/runner/resources/app_icon.ico');assert.equal(ico.readUInt16LE(0),0);assert.equal(ico.readUInt16LE(2),1);assert.equal(ico.readUInt16LE(4),6);
  let end=102;
  for(let i=0;i<6;i++) {
    const at=6+i*16,offset=ico.readUInt32LE(at+12),length=ico.readUInt32LE(at+8),size=ico[at]||256;
    assert.equal(offset,end);end+=length;assert.ok(end<=ico.length);
    const metadata=await sharp(ico.subarray(offset,end)).metadata();assert.equal(metadata.format,'png');assert.equal(metadata.width,size);assert.equal(metadata.height,size);
  }
  assert.equal(end,ico.length);
});
