import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const args=process.argv.slice(2),arg=name=>args[args.indexOf(name)+1];
if(!args.includes('--icon')||!args.includes('--logo'))throw new Error('Use --icon canonical/icon.jpeg --logo canonical/logo.jpeg');
const icon=await fs.readFile(arg('--icon')),logo=await fs.readFile(arg('--logo'));
const metadata=await Promise.all([sharp(icon).metadata(),sharp(logo).metadata()]);
if(metadata.some(row=>row.format!=='jpeg'||!row.width||!row.height))throw new Error('Canonical JPEG sources required');
const write=async(relative,bytes)=>{const target=path.join(root,relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes);};
const resized=async(source,size)=>sharp(source).rotate().resize(size,size,{fit:'contain',background:'#061329'}).png().toBuffer();
const padded=async(size,ratio)=>sharp({create:{width:size,height:size,channels:4,background:'#061329'}}).composite([{input:await resized(icon,Math.round(size*ratio)),gravity:'centre'}]).png().toBuffer();
await write('mobile/assets/branding/advise_app_icon.jpeg',icon);
await write('mobile/assets/branding/advise_full_logo.jpeg',logo);
await write('mobile/assets/branding/advise_app_icon.png',await resized(icon,512));
await write('mobile/assets/branding/advise_full_logo.png',await sharp(logo).rotate().png().toBuffer());
// Compatibility fixture/source path now contains the same canonical full logo.
await write('mobile/assets/advise_logo.jpg',logo);
for(const [density,size]of [['mdpi',48],['hdpi',72],['xhdpi',96],['xxhdpi',144],['xxxhdpi',192]]) {
  for(const name of ['ic_launcher','ic_launcher_round'])await write(`mobile/android/app/src/main/res/mipmap-${density}/${name}.png`,await resized(icon,size));
}
await write('mobile/android/app/src/main/res/drawable-nodpi/advise_app_icon_foreground.png',await padded(432,.61));
await write('mobile/android/app/src/main/res/drawable-nodpi/advise_splash_logo.png',await sharp(logo).resize(240,240,{fit:'inside'}).png().toBuffer());
const adaptive='<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/advise_icon_background"/><foreground android:drawable="@drawable/advise_app_icon_foreground"/></adaptive-icon>\n';
for(const name of ['ic_launcher','ic_launcher_round'])await write(`mobile/android/app/src/main/res/mipmap-anydpi-v26/${name}.xml`,adaptive);
await write('mobile/android/app/src/main/res/values/branding.xml','<resources><color name="advise_icon_background">#061329</color></resources>\n');
for(const size of [192,512]) {
  await write(`mobile/web/icons/Icon-${size}.png`,await resized(icon,size));
  await write(`mobile/web/icons/Icon-maskable-${size}.png`,await padded(size,.8));
}
await write('mobile/web/favicon.png',await resized(icon,32));
const sizes=[16,32,48,64,128,256],frames=await Promise.all(sizes.map(size=>resized(icon,size)));
const header=Buffer.alloc(6+sizes.length*16);header.writeUInt16LE(1,2);header.writeUInt16LE(sizes.length,4);
let offset=header.length;
for(let i=0;i<sizes.length;i++) {const at=6+i*16;header[at]=sizes[i]%256;header[at+1]=sizes[i]%256;header.writeUInt16LE(1,at+4);header.writeUInt16LE(32,at+6);header.writeUInt32LE(frames[i].length,at+8);header.writeUInt32LE(offset,at+12);offset+=frames[i].length;}
await write('mobile/windows/runner/resources/app_icon.ico',Buffer.concat([header,...frames]));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
await write('mobile/assets/branding/canonical.json',JSON.stringify({appIcon:{source:'icon.jpeg',sha256:hash(icon),width:metadata[0].width,height:metadata[0].height},fullLogo:{source:'logo.jpeg',sha256:hash(logo),width:metadata[1].width,height:metadata[1].height},manifestSha256:hash(await fs.readFile(path.join(root,'mobile/web/manifest.json')))},null,2)+'\n');
console.log('Canonical JPEGs preserved; real PNG and six-frame ICO derivatives generated. Manifest untouched.');
