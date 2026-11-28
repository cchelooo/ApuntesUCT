// PostgreSQL + HTTP reales. Esquemas desechables; no usa las tablas habituales del entorno.
require('reflect-metadata');
const {test}=require('node:test');const assert=require('node:assert/strict');
const {randomUUID,generateKeyPairSync}=require('node:crypto');
const {mkdtempSync,writeFileSync,rmSync}=require('node:fs');const {tmpdir}=require('node:os');const {resolve,join}=require('node:path');const {execFileSync}=require('node:child_process');
const {Test}=require('@nestjs/testing');const {sign}=require('jsonwebtoken');
const root=resolve(__dirname,'..');const load=(s,p)=>require(resolve(root,s,'dist',s==='auth-service'?'src':'',p));
const {PrismaClient:Q}=require('../quality-service/node_modules/.prisma/quality-client');
const {PrismaClient:M}=require('../material-service/node_modules/.prisma/material-client');const {PrismaClient:A}=require('../node_modules/.prisma/auth-client');
test('Favoritos: identidad, visibilidad, aislamiento y concurrencia',{timeout:180000},async t=>{
 const env={...process.env},apps=[],clients=[];const schema='favorites_test_'+randomUUID().replaceAll('-','');const dir=mkdtempSync(join(tmpdir(),'quality-favorites-'));
 const configs=['QUALITY','AUTH','MATERIAL'].map(name=>{const raw=process.env[`FAVORITES_TEST_${name}_DATABASE_URL`];assert.ok(raw,`Falta FAVORITES_TEST_${name}_DATABASE_URL (usar conexión real, no marcadores)`);const url=new URL(raw);assert.equal(url.pathname,`/${name.toLowerCase()}_db`);assert.ok(['postgres:','postgresql:'].includes(url.protocol));url.searchParams.set('schema',schema);return {name,url:url.toString()};});
 const keys=generateKeyPairSync('rsa',{modulusLength:2048});writeFileSync(join(dir,'auth.pem'),keys.privateKey.export({type:'pkcs8',format:'pem'}),{mode:0o600});
 Object.assign(process.env,{NODE_ENV:'test',JWT_PRIVATE_KEY_PATH:join(dir,'auth.pem'),JWT_ISSUER:'favorites-auth',JWT_AUDIENCE:'favorites-api'});
 async function start(module,setup){const app=module.createNestApplication({logger:false});if(setup)setup(app);await app.listen(0,'127.0.0.1');apps.push(app);return app;}
 let base,q,m,a,tokens,users,material,authApp,matApp,qualityApp;const materialReads=[];
 async function http(path,token,method='GET',body,key){const response=await fetch(base+'/api/v1/quality'+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...(key?{'Idempotency-Key':key}:{}),...(body!==undefined?{'Content-Type':'application/json'}:{})},...(body!==undefined?{body:JSON.stringify(body)}:{})});return {status:response.status,body:response.status===204?null:await response.json(),headers:response.headers};}
 const put=(id,token)=>http(`/materials/${id}/favorite`,token,'PUT');
 const del=(id,token)=>http(`/materials/${id}/favorite`,token,'DELETE');
 const list=(token,query='')=>http('/favorites/me'+query,token);
 let student,other,moderator,admin,author;
 async function newMaterial(owner=users.author.id,status='PUBLISHED'){return m.material.create({data:{uploaderId:owner,subjectId:'subject-test',materialTypeId:material.materialTypeId,title:'Recurso',academicYear:2026,status,externalLink:'https://example.invalid/resource'}});}
 try {
  for(const c of configs)execFileSync(process.execPath,[require.resolve('prisma/build/index.js'),'migrate','deploy'],{cwd:resolve(root,c.name.toLowerCase()+'-service'),env:{...process.env,DATABASE_URL:c.url},stdio:'pipe',timeout:60000});
  q=new Q({datasources:{db:{url:configs[0].url}}});a=new A({datasources:{db:{url:configs[1].url}}});m=new M({datasources:{db:{url:configs[2].url}}});clients.push(q,a,m);
  users={};for(const [name,role] of [['student','STUDENT'],['other','STUDENT'],['moderator','MODERATOR'],['admin','ADMIN'],['author','MODERATOR']])users[name]=await a.user.create({data:{name,email:randomUUID()+'@uct.cl',role,passwordHash:'unused'}});
  const authModule=await Test.createTestingModule({controllers:[load('auth-service','presentation/auth/access-context.controller').AccessContextController],providers:[load('auth-service','infrastructure/security/access-token.service').AccessTokenService,{provide:load('auth-service','infrastructure/prisma/prisma.service').PrismaService,useValue:a}]}).compile();
  authApp=await start(authModule,app=>app.setGlobalPrefix('api/v1'));process.env.QUALITY_FAVORITES_AUTH_URL=await authApp.getUrl();tokens=authApp.get(load('auth-service','infrastructure/security/access-token.service').AccessTokenService);
  [student,other,moderator,admin,author]=['student','other','moderator','admin','author'].map(n=>tokens.issue(users[n]));
  const matModule=await Test.createTestingModule({controllers:[load('material-service','presentation/materials/materials.controller').MaterialsController],providers:[load('material-service','application/services/materials.service').MaterialsService,{provide:load('material-service','infrastructure/prisma/prisma.service').PrismaService,useValue:m},{provide:load('material-service','application/ports/object-storage.port').ObjectStorage,useValue:{}}]}).compile();
  matApp=await start(matModule,app=>{app.setGlobalPrefix('api/v1');app.use((req,_res,next)=>{materialReads.push(req.url);next();});});process.env.QUALITY_FAVORITES_MATERIAL_URL=await matApp.getUrl();
  const type=await m.materialType.findUniqueOrThrow({where:{name:'LINK'}});material={materialTypeId:type.id};material=await newMaterial();
  process.env.DATABASE_URL=configs[0].url;
  const qm=await Test.createTestingModule({imports:[load('quality-service','app.module').AppModule]}).overrideProvider(load('quality-service','infrastructure/prisma/prisma.service').PrismaService).useValue(q).compile();qualityApp=await start(qm,load('quality-service','setup-app').setupApp);
  process.env.QUALITY_SERVICE_URL=await qualityApp.getUrl();
  const gm=await Test.createTestingModule({imports:[load('api-gateway','app.module').AppModule]}).compile();const gateway=await start(gm,load('api-gateway','configure-routes').configureRoutes);base=await gateway.getUrl();
  await t.test('401 sin token, inválido, expirado, mock o firma ajena; no acepta headers falsos',async()=>{
   for(const method of ['GET','PUT','DELETE']){const path=method==='GET'?'/favorites/me':`/materials/${material.id}/favorite`;assert.equal((await http(path,undefined,method)).status,401);assert.equal((await http(path,'broken',method)).status,401);}
   for(const payload of [{mock:true},{exp:1}]){const token=sign({sub:users.student.id,email:users.student.email,role:'STUDENT',...payload},keys.privateKey,{algorithm:'RS256',issuer:'favorites-auth',audience:'favorites-api',...(payload.exp?{}:{expiresIn:60})});assert.equal((await list(token)).status,401);}
   const foreign=generateKeyPairSync('rsa',{modulusLength:2048});const token=sign({sub:users.student.id,email:users.student.email,role:'STUDENT'},foreign.privateKey,{algorithm:'RS256',issuer:'favorites-auth',audience:'favorites-api',expiresIn:60});assert.equal((await list(token)).status,401);
   const res=await fetch(base+'/api/v1/quality/favorites/me',{headers:{'x-user-id':users.admin.id,'x-role':'ADMIN'}});assert.equal(res.status,401);assert.equal(res.headers.get('WWW-Authenticate'),'Bearer');
  });
  let favorite;
  await t.test('PUT crea 201, repite 200 sin alterar id/createdAt ni Material',async()=>{
   const before=await m.material.findUnique({where:{id:material.id}});const created=await put(material.id,student);assert.equal(created.status,201);favorite=created.body;
   assert.deepEqual(Object.keys(favorite).sort(),['available','createdAt','id','materialId']);assert.equal(favorite.available,true);assert.equal(favorite.materialId,material.id);assert.equal(created.headers.get('cache-control'),'no-store');
   const repeated=await put(material.id,student);assert.equal(repeated.status,200);assert.deepEqual(repeated.body,favorite);assert.deepEqual(await m.material.findUnique({where:{id:material.id}}),before);
   assert.equal(await q.favorite.count({where:{materialId:material.id,userId:users.student.id}}),1);
  });
  await t.test('STUDENT/MODERATOR/ADMIN pueden guardar; se permite material propio',async()=>{
   assert.equal((await put(material.id,moderator)).status,201);assert.equal((await put(material.id,admin)).status,201);assert.equal((await put(material.id,author)).status,201);
  });
  await t.test('lista y borrado siempre propios, no acepta userId ni cuerpo',async()=>{
   assert.equal((await list(other)).body.total,0);assert.equal((await del(material.id,other)).status,204);assert.equal((await list(student)).body.total,1);
   assert.equal((await http(`/materials/${material.id}/favorite?userId=${users.student.id}`,other,'DELETE')).status,400);
   for(const body of [{userId:users.student.id},{},null,[]])assert.equal((await http(`/materials/${material.id}/favorite`,other,'PUT',body)).status,400);
   assert.equal((await http(`/materials/${material.id}/favorite`,other,'DELETE',{userId:users.student.id})).status,400);
   assert.equal((await list(other,'?userId='+users.student.id)).status,400);
  });
  await t.test('rechaza material inexistente/oculto y UUID inválido',async()=>{
   assert.equal((await put(randomUUID(),student)).status,404);assert.equal((await put('invalid',student)).status,400);assert.equal((await del('invalid',student)).status,400);
   for(const status of ['PENDING_REVIEW','REJECTED','WITHDRAWN'])assert.equal((await put((await newMaterial(users.author.id,status)).id,student)).status,404);
  });
  await t.test('favorito oculto se conserva sin metadatos; PUT repetido pasa a 404',async()=>{
   await m.material.update({where:{id:material.id},data:{status:'WITHDRAWN'}});
   const result=await list(student);assert.equal(result.status,200);assert.equal(result.body.total,1);assert.deepEqual(result.body.items,[{...favorite,available:false}]);assert.equal((await put(material.id,student)).status,404);
   assert.equal(await q.favorite.count({where:{materialId:material.id,userId:users.student.id}}),1);
   await m.material.update({where:{id:material.id},data:{status:'PUBLISHED'}});assert.deepEqual((await put(material.id,student)).body,favorite);
  });
  await t.test('referencia a material eliminado conserva total y available=false',async()=>{
   const missing=randomUUID();const f=await q.favorite.create({data:{userId:users.other.id,materialId:missing}});const result=await list(other);assert.equal(result.body.total,1);assert.equal(result.body.items[0].id,f.id);assert.equal(result.body.items[0].available,false);assert.equal((await del(missing,other)).status,204);
  });
  await t.test('paginación coherente, desempate id DESC y sólo consulta la página',async()=>{
   const ids=[];for(let i=0;i<7;i++)ids.push((await newMaterial()).id);
   const createdAt=new Date('2026-11-01T12:00:00Z');for(const id of ids)await q.favorite.create({data:{userId:users.other.id,materialId:id,createdAt}});
   const sorted=await q.favorite.findMany({where:{userId:users.other.id},orderBy:[{createdAt:'desc'},{id:'desc'}]});materialReads.length=0;
   const second=await list(other,'?page=2&pageSize=3');assert.equal(second.body.total,7);assert.deepEqual(second.body.items.map(x=>x.id),sorted.slice(3,6).map(x=>x.id));assert.equal(materialReads.length,3);
   materialReads.length=0;const outside=await list(other,'?page=99&pageSize=3');assert.equal(outside.status,200);assert.deepEqual(outside.body.items,[]);assert.equal(outside.body.total,7);assert.equal(materialReads.length,0);
   for(const query of ['page=0','page=1&page=2','pageSize=101','page=','page=1.5','page=2147483647&pageSize=100','sort=id'])assert.equal((await list(other,'?'+query)).status,400);
  });
  await t.test('PUT concurrentes producen una fila, un 201 y cuatro 200',async()=>{
   const mat=await newMaterial();const results=await Promise.all(Array.from({length:5},()=>put(mat.id,student)));assert.equal(results.filter(x=>x.status===201).length,1);assert.equal(results.filter(x=>x.status===200).length,4);assert.equal(new Set(results.map(x=>x.body.id)).size,1);
   await assert.rejects(q.favorite.create({data:{userId:users.student.id,materialId:mat.id}}),{code:'P2002'});
  });
  await t.test('DELETE repetido devuelve 204 y cuerpo vacío',async()=>{
   const mat=await newMaterial();await put(mat.id,student);for(let i=0;i<2;i++){const result=await del(mat.id,student);assert.equal(result.status,204);assert.equal(result.body,null);}
   assert.equal((await del(randomUUID(),student)).status,204);
  });
  await t.test('PUT/DELETE concurrentes no producen duplicados ni afectan a otro usuario',async()=>{
   const mat=await newMaterial();await put(mat.id,other);const results=await Promise.all([put(mat.id,student),del(mat.id,student),put(mat.id,student),del(mat.id,student)]);
   assert.ok(results.every(x=>[200,201,204].includes(x.status)));assert.ok(await q.favorite.count({where:{userId:users.student.id,materialId:mat.id}})<=1);assert.equal(await q.favorite.count({where:{userId:users.other.id,materialId:mat.id}}),1);
   await del(mat.id,student);assert.equal(await q.favorite.count({where:{userId:users.student.id,materialId:mat.id}}),0);
  });
  await t.test('cuenta inactiva, rol actual y token revocado se verifican en cada operación',async()=>{
   await a.user.update({where:{id:users.student.id},data:{active:false}});for(const result of [await list(student),await put(material.id,student),await del(material.id,student)])assert.equal(result.status,403);
   await a.user.update({where:{id:users.student.id},data:{active:true,tokenVersion:1}});assert.equal((await list(student)).status,401);student=tokens.issue({...users.student,tokenVersion:1});assert.equal((await list(student)).status,200);
   await a.user.update({where:{id:users.admin.id},data:{role:'STUDENT'}});assert.equal((await list(admin)).status,200); // Todos los roles conservan sus favoritos propios.
  });
  await t.test('respuesta inconsistente de Material devuelve 502, sin false ni escrituras',async()=>{
   const {createServer}=require('node:http');const server=createServer((_req,res)=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify({id:'wrong',status:'PUBLISHED'}));});await new Promise(r=>server.listen(0,'127.0.0.1',r));const previous=process.env.QUALITY_FAVORITES_MATERIAL_URL;process.env.QUALITY_FAVORITES_MATERIAL_URL=`http://127.0.0.1:${server.address().port}`;
   try{const before=await q.favorite.count();assert.equal((await put(randomUUID(),student)).status,502);assert.equal((await list(student)).status,502);assert.equal(await q.favorite.count(),before);}finally{process.env.QUALITY_FAVORITES_MATERIAL_URL=previous;await new Promise(r=>server.close(r));}
  });
  await t.test('Material caído: PUT/listado 503, DELETE 204 sin consultar Material',async()=>{
   await matApp.close();const before=await q.favorite.count();assert.equal((await put(randomUUID(),student)).status,503);assert.equal((await list(student)).status,503);assert.equal(await q.favorite.count(),before);assert.equal((await del(material.id,student)).status,204);assert.equal((await del(randomUUID(),student)).status,204);
  });
  await t.test('Auth caído: falla cerrado en todas las rutas',async()=>{
   await authApp.close();for(const result of [await list(student),await put(material.id,student),await del(material.id,student)])assert.equal(result.status,503);
  });
  await t.test('Swagger contiene las tres rutas y deploy repetido conserva favoritos',async()=>{
   const spec=await (await fetch((await qualityApp.getUrl())+'/api/docs-json')).json();assert.ok(spec.paths['/api/v1/quality/favorites/me'].get);assert.ok(spec.paths['/api/v1/quality/materials/{materialId}/favorite'].put.responses['201']);assert.ok(spec.paths['/api/v1/quality/materials/{materialId}/favorite'].delete.responses['204']);
   const before=await q.favorite.count();execFileSync(process.execPath,[require.resolve('prisma/build/index.js'),'migrate','deploy'],{cwd:resolve(root,'quality-service'),env:{...process.env,DATABASE_URL:configs[0].url},stdio:'pipe'});assert.equal(await q.favorite.count(),before);
  });
 }finally{
  for(const app of apps.reverse())await app.close();
  for(const client of clients){try{await client.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);}finally{await client.$disconnect();}}
  rmSync(dir,{recursive:true,force:true});for(const k of Object.keys(process.env))if(!(k in env))delete process.env[k];Object.assign(process.env,env);
 }
});
