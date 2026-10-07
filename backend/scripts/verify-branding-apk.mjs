// Read-only check of a locally generated APK. No extraction, credentials or device.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {inflateRawSync} from 'node:zlib';
import sharp from 'sharp';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const apk=await fs.readFile(process.argv[2]||path.join(root,'mobile/build/app/outputs/flutter-apk/app-release.apk'));
const eocd=apk.lastIndexOf(Buffer.from([80,75,5,6]));
if(eocd<0||eocd+22+apk.readUInt16LE(eocd+20)!==apk.length)throw new Error('Invalid APK ZIP footer');
let at=apk.readUInt32LE(eocd+16);const entries=[];
for(let i=0;i<apk.readUInt16LE(eocd+10);i++) {
  if(apk.readUInt32LE(at)!==0x02014b50)throw new Error('Invalid ZIP directory');
  const nameLength=apk.readUInt16LE(at+28),extra=apk.readUInt16LE(at+30),comment=apk.readUInt16LE(at+32);
  entries.push({name:apk.toString('utf8',at+46,at+46+nameLength),method:apk.readUInt16LE(at+10),size:apk.readUInt32LE(at+20),offset:apk.readUInt32LE(at+42)});
  at+=46+nameLength+extra+comment;
}
function read(entry) {
  const start=entry.offset+30+apk.readUInt16LE(entry.offset+26)+apk.readUInt16LE(entry.offset+28);
  const bytes=apk.subarray(start,start+entry.size);
  if(entry.method===0)return bytes;
  if(entry.method===8)return inflateRawSync(bytes,{maxOutputLength:6*1024*1024});
  throw new Error('Unsupported APK compression');
}
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const pixels=async bytes=>hash(await sharp(bytes).ensureAlpha().raw().toBuffer());
const packaged=new Set();
for(const entry of entries.filter(row=>row.name.startsWith('res/')&&row.name.endsWith('.png')))packaged.add(await pixels(read(entry)));
for(const density of ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']) {
  const icon=await fs.readFile(path.join(root,`mobile/android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
  if(!packaged.has(await pixels(icon)))throw new Error(`Launcher ${density} pixels missing from APK`);
}
for(const name of ['advise_app_icon_foreground','advise_splash_logo']) {
  if(!packaged.has(await pixels(await fs.readFile(path.join(root,`mobile/android/app/src/main/res/drawable-nodpi/${name}.png`)))))throw new Error(`Android ${name} pixels missing from APK`);
}
for(const name of ['advise_full_logo','advise_app_icon']) {
  const entry=entries.find(row=>row.name===`assets/flutter_assets/assets/branding/${name}.png`);
  if(!entry||hash(read(entry))!==hash(await fs.readFile(path.join(root,`mobile/assets/branding/${name}.png`))))throw new Error('Canonical Flutter PNG mismatch');
}
console.log('APK verified: canonical Flutter PNG hashes, all 5 launcher densities, adaptive foreground and splash pixels.');
