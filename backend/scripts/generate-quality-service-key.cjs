// Generates a separate development service identity. Never overwrites existing keys.
const {generateKeyPairSync}=require('node:crypto');
const {mkdirSync,writeFileSync}=require('node:fs');
const {resolve}=require('node:path');
const folder=process.argv[2];
if(!folder)throw Error('Indica una carpeta privada fuera del repositorio.');
const target=resolve(folder);mkdirSync(target,{recursive:true});
const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:3072});
writeFileSync(resolve(target,'quality-service-private.pem'),privateKey.export({type:'pkcs8',format:'pem'}),{mode:0o600,flag:'wx'});
writeFileSync(resolve(target,'quality-service-public.pem'),publicKey.export({type:'spki',format:'pem'}),{mode:0o644,flag:'wx'});
console.log('Claves de Quality creadas. Mantén la clave privada fuera de Git.');
