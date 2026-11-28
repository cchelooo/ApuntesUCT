// PostgreSQL + HTTP reales. Esquemas desechables; no usa las tablas habituales del entorno.
require('reflect-metadata');
const {test}=require('node:test');const assert=require('node:assert/strict');
const {randomUUID,generateKeyPairSync}=require('node:crypto');
const {mkdtempSync,writeFileSync,rmSync}=require('node:fs');const {tmpdir}=require('node:os');const {resolve,join}=require('node:path');const {execFileSync}=require('node:child_process');
const {Test}=require('@nestjs/testing');const {sign}=require('jsonwebtoken');
const root=resolve(__dirname,'..');const load=(s,p)=>require(resolve(root,s,'dist',s==='auth-service'?'src':'',p));
const {PrismaClient:Q}=require('../quality-service/node_modules/.prisma/quality-client');
const {PrismaClient:M}=require('../material-service/node_modules/.prisma/material-client');const {PrismaClient:A}=require('../node_modules/.prisma/auth-client');
test('Reportes: creación, consulta, resolución, concurrencia y autorización vigente',{timeout:180000},async t=>{
 const env={...process.env},apps=[],clients=[];const schema='reports_test_'+randomUUID().replaceAll('-','');const dir=mkdtempSync(join(tmpdir(),'quality-reports-'));
 const configs=['QUALITY','AUTH','MATERIAL'].map(name=>{const raw=process.env[`REPORTS_TEST_${name}_DATABASE_URL`];assert.ok(raw,`Falta REPORTS_TEST_${name}_DATABASE_URL (usar conexión real, no marcadores)`);const url=new URL(raw);assert.equal(url.pathname,`/${name.toLowerCase()}_db`);assert.ok(['postgres:','postgresql:'].includes(url.protocol));url.searchParams.set('schema',schema);return {name,url:url.toString()};});
 const keys=generateKeyPairSync('rsa',{modulusLength:2048});writeFileSync(join(dir,'auth.pem'),keys.privateKey.export({type:'pkcs8',format:'pem'}),{mode:0o600});
 Object.assign(process.env,{NODE_ENV:'test',JWT_PRIVATE_KEY_PATH:join(dir,'auth.pem'),JWT_ISSUER:'reports-auth',JWT_AUDIENCE:'reports-api'});
 async function start(module,setup){const app=module.createNestApplication({logger:false});if(setup)setup(app);await app.listen(0,'127.0.0.1');apps.push(app);return app;}
 let base,q,m,a,tokens,users,material,authApp,matApp,qualityApp;
 async function http(path,token,method='GET',body,key){const response=await fetch(base+'/api/v1/quality'+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...(key?{'Idempotency-Key':key}:{}),...(body!==undefined?{'Content-Type':'application/json'}:{})},...(body!==undefined?{body:JSON.stringify(body)}:{})});return {status:response.status,body:await response.json(),headers:response.headers};}
 const create=(id,token,key=randomUUID(),body={reason:'COPYRIGHT',details:'Prueba'})=>http(`/materials/${id}/reports`,token,'POST',body,key);
 const patch=(r,token,status='RESOLVED',key=randomUUID(),note='Evaluado')=>http(`/moderation/reports/${r.id}`,token,'PATCH',{status,expectedUpdatedAt:r.updatedAt,resolutionNote:note},key);
 let student,other,moderator,admin,author;
 async function newMaterial(owner=users.author.id,status='PUBLISHED'){return m.material.create({data:{uploaderId:owner,subjectId:'subject-test',materialTypeId:material.materialTypeId,title:'Recurso',academicYear:2026,status,externalLink:'https://example.invalid/resource'}});}
 try {
  for(const c of configs)execFileSync(process.execPath,[require.resolve('prisma/build/index.js'),'migrate','deploy'],{cwd:resolve(root,c.name.toLowerCase()+'-service'),env:{...process.env,DATABASE_URL:c.url},stdio:'pipe',timeout:60000});
  q=new Q({datasources:{db:{url:configs[0].url}}});a=new A({datasources:{db:{url:configs[1].url}}});m=new M({datasources:{db:{url:configs[2].url}}});clients.push(q,a,m);
  users={};for(const [name,role] of [['student','STUDENT'],['other','STUDENT'],['moderator','MODERATOR'],['admin','ADMIN'],['author','MODERATOR']])users[name]=await a.user.create({data:{name,email:randomUUID()+'@uct.cl',role,passwordHash:'unused'}});
  const authModule=await Test.createTestingModule({controllers:[load('auth-service','presentation/auth/access-context.controller').AccessContextController],providers:[load('auth-service','infrastructure/security/access-token.service').AccessTokenService,{provide:load('auth-service','infrastructure/prisma/prisma.service').PrismaService,useValue:a}]}).compile();
  authApp=await start(authModule,app=>app.setGlobalPrefix('api/v1'));process.env.QUALITY_REPORTS_AUTH_URL=await authApp.getUrl();tokens=authApp.get(load('auth-service','infrastructure/security/access-token.service').AccessTokenService);
  [student,other,moderator,admin,author]=['student','other','moderator','admin','author'].map(n=>tokens.issue(users[n]));
  const matModule=await Test.createTestingModule({controllers:[load('material-service','presentation/materials/materials.controller').MaterialsController],providers:[load('material-service','application/services/materials.service').MaterialsService,{provide:load('material-service','infrastructure/prisma/prisma.service').PrismaService,useValue:m},{provide:load('material-service','application/ports/object-storage.port').ObjectStorage,useValue:{}}]}).compile();
  matApp=await start(matModule,app=>app.setGlobalPrefix('api/v1'));process.env.QUALITY_REPORTS_MATERIAL_URL=await matApp.getUrl();
  const type=await m.materialType.findUniqueOrThrow({where:{name:'LINK'}});material={materialTypeId:type.id};material=await newMaterial();
  process.env.DATABASE_URL=configs[0].url;
  const qm=await Test.createTestingModule({imports:[load('quality-service','app.module').AppModule]}).overrideProvider(load('quality-service','infrastructure/prisma/prisma.service').PrismaService).useValue(q).compile();qualityApp=await start(qm,load('quality-service','setup-app').setupApp);
  process.env.QUALITY_SERVICE_URL=await qualityApp.getUrl();
  const gm=await Test.createTestingModule({imports:[load('api-gateway','app.module').AppModule]}).compile();const gateway=await start(gm,load('api-gateway','configure-routes').configureRoutes);base=await gateway.getUrl();
  await t.test('401/403 antes de consultar recursos; firma, vencimiento, mock y headers falsos',async()=>{
   assert.equal((await http('/reports/me')).status,401);assert.equal((await http('/moderation/reports',student)).status,403);
   assert.equal((await http('/moderation/reports/not-a-uuid',student,'PATCH',{},randomUUID())).status,403);
   for(const payload of [{mock:true},{exp:1}]){const token=sign({sub:users.student.id,email:users.student.email,role:'STUDENT',...payload},keys.privateKey,{algorithm:'RS256',issuer:'reports-auth',audience:'reports-api',...(payload.exp?{}:{expiresIn:60})});assert.equal((await http('/reports/me',token)).status,401);}
   assert.equal((await http('/reports/me','broken')).status,401);
   const spoof=await fetch(base+'/api/v1/quality/moderation/reports',{headers:{'x-role':'ADMIN','x-user-id':users.admin.id}});assert.equal(spoof.status,401);
  });
  let report,key=randomUUID();
  await t.test('JSON malformado y Swagger respetan el contrato de Quality', async()=>{
   const response=await fetch((await qualityApp.getUrl())+'/api/v1/quality/materials/'+material.id+'/reports',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+student},body:'{invalid'});
   assert.equal(response.status,400);const error=await response.json();assert.equal(error.code,'VALIDATION_ERROR');assert.ok(error.requestId);
   const spec=await (await fetch((await qualityApp.getUrl())+'/api/docs-json')).json();
   assert.ok(spec.paths['/api/v1/quality/moderation/reports/{reportId}'].patch.responses['200'].content['application/json'].schema.properties.resolutionNote);
  });
  await t.test('creación 201 con identidad verificada y sin efectos en Material',async()=>{
   const before=await m.material.findUniqueOrThrow({where:{id:material.id}});const result=await create(material.id,student,key);assert.equal(result.status,201);report=result.body;
   assert.equal(report.userId,users.student.id);assert.equal(report.status,'OPEN');assert.equal(report.resolutionNote,null);assert.equal(result.headers.get('cache-control'),'no-store');assert.ok(!('materialUploaderId' in report));
   assert.deepEqual(await m.material.findUniqueOrThrow({where:{id:material.id}}),before);assert.equal(await q.reportHistory.count({where:{reportId:report.id}}),1);
  });
  await t.test('replay, conflicto de clave y reporte abierto duplicado',async()=>{
   assert.deepEqual((await create(material.id,student,key)).body,report);
   assert.equal((await create(material.id,student,key,{reason:'OTHER',details:'Distinto'})).status,409);
   assert.equal((await create(material.id,student)).body.code,'REPORT_ALREADY_OPEN');
  });
  await t.test('consulta propia, ajena 404, moderadores, filtros y paginación estricta',async()=>{
   assert.equal((await http('/reports/'+report.id,other)).status,404);assert.equal((await http('/reports/'+report.id,moderator)).status,200);
   assert.equal((await http('/reports/me',student)).body.total,1);assert.equal((await http('/reports/me',other)).body.total,0);
   assert.equal((await http('/moderation/reports?status=OPEN',admin)).body.items[0].id,report.id);
   assert.equal((await http('/reports/me?page=99',student)).body.items.length,0);
   for(const query of ['page=0','page=1&page=2','pageSize=101','status=OPEN','sort=id','page=2147483647&pageSize=100'])assert.equal((await http('/reports/me?'+query,student)).status,400);
  });
  await t.test('entrada inválida, material oculto/inexistente y motivos',async()=>{
   const hidden=await newMaterial(users.author.id,'PENDING_REVIEW');assert.equal((await create(hidden.id,student)).status,404);assert.equal((await create(randomUUID(),student)).status,404);
   const fresh=await newMaterial();for(const body of [{reason:'OTHER'},{reason:'COPYRIGHT',userId:users.admin.id},{reason:'INVALID'},{reason:'OTHER',details:' '},{reason:'COPYRIGHT',details:'x'.repeat(2001)}])assert.equal((await create(fresh.id,student,randomUUID(),body)).status,400);
   assert.equal((await http('/materials/'+fresh.id+'/reports',student,'POST',{reason:'COPYRIGHT'})).status,400);
  });
  await t.test('autor y denunciante no tramitan; tampoco ADMIN tiene excepción',async()=>{
   assert.equal((await patch(report,author)).status,403);
   const own=await newMaterial(users.admin.id);const r=(await create(own.id,other)).body;assert.equal((await patch(r,admin)).status,403);
   const ownReport=(await create((await newMaterial()).id,admin)).body;assert.equal((await patch(ownReport,admin)).status,403);
  });
  await t.test('IN_REVIEW y RESOLVED, nota, timestamp, historial y replay histórico',async()=>{
   assert.equal((await patch(report,moderator,'RESOLVED',randomUUID(),' ')).status,400);
   const mutationKey=randomUUID();const inReview=await patch(report,moderator,'IN_REVIEW',mutationKey);assert.equal(inReview.status,200);assert.ok(Date.parse(inReview.body.updatedAt)>Date.parse(report.updatedAt));
   assert.equal((await patch(report,admin)).status,409);
   const resolved=await patch(inReview.body,admin);assert.equal(resolved.body.status,'RESOLVED');
   const replay=await patch(report,moderator,'IN_REVIEW',mutationKey);assert.deepEqual(replay.body,inReview.body);
   assert.equal((await q.report.findUnique({where:{id:report.id}})).status,'RESOLVED');assert.equal((await patch(resolved.body,moderator,'IN_REVIEW')).status,409);
   const history=await q.reportHistory.findMany({where:{reportId:report.id},orderBy:{createdAt:'asc'}});assert.deepEqual(history.map(x=>x.status),['OPEN','IN_REVIEW','RESOLVED']);assert.equal(history[2].actorId,users.admin.id);
   assert.deepEqual((await create(material.id,student,key)).body,report);assert.equal((await create(material.id,student)).status,201);
   assert.equal((await m.material.findUnique({where:{id:material.id}})).status,'PUBLISHED');
  });
  await t.test('material retirado después del reporte: consulta y resolución sin filtrar contenido',async()=>{
   const mat=await newMaterial();const r=(await create(mat.id,student)).body;await m.material.update({where:{id:mat.id},data:{status:'WITHDRAWN'}});
   assert.equal((await http('/reports/'+r.id,student)).status,200);const resolved=await patch(r,admin,'DISMISSED');assert.equal(resolved.status,200);assert.equal(resolved.body.status,'DISMISSED');assert.ok(!('title' in resolved.body));assert.equal((await m.material.findUnique({where:{id:mat.id}})).status,'WITHDRAWN');
  });
  await t.test('5 creaciones concurrentes: misma clave, un registro y un historial',async()=>{
   const mat=await newMaterial(),k=randomUUID();const results=await Promise.all(Array.from({length:5},()=>create(mat.id,student,k)));assert.equal(results.filter(r=>r.status===201).length,1);assert.equal(results.filter(r=>r.status===200).length,4);assert.equal(new Set(results.map(r=>r.body.id)).size,1);assert.equal(await q.report.count({where:{materialId:mat.id}}),1);
  });
  await t.test('la misma clave en usuarios distintos no comparte respuestas',async()=>{
   const mat=await newMaterial(),k=randomUUID();const first=await create(mat.id,student,k);const second=await create(mat.id,other,k);assert.equal(first.status,201);assert.equal(second.status,201);assert.notEqual(first.body.id,second.body.id);assert.equal(second.body.userId,users.other.id);
  });
  await t.test('claves distintas concurrentes: índice parcial mantiene un único abierto',async()=>{
   const mat=await newMaterial();const results=await Promise.all([create(mat.id,student),create(mat.id,student)]);assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);
   await assert.rejects(q.report.create({data:{materialId:mat.id,userId:users.student.id,reason:'COPYRIGHT'}}),{code:'P2002'});
  });
  await t.test('dos resoluciones sobre misma fecha: una aplica y otra conflicto',async()=>{
   const r=(await create((await newMaterial()).id,student)).body;
   const results=await Promise.all([patch(r,admin),patch(r,moderator,'DISMISSED')]);assert.deepEqual(results.map(x=>x.status).sort(),[200,409]);assert.equal(await q.reportHistory.count({where:{reportId:r.id}}),2);
  });
  await t.test('rollback de historial no deja reporte ni clave parciales',async()=>{
   await q.$executeRawUnsafe(`CREATE FUNCTION "${schema}".reject_history() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected'; END $$`);
   await q.$executeRawUnsafe('CREATE TRIGGER reject_history BEFORE INSERT ON report_history FOR EACH ROW EXECUTE FUNCTION reject_history()');
   const mat=await newMaterial(),k=randomUUID();assert.equal((await create(mat.id,student,k)).status,503);assert.equal(await q.report.count({where:{materialId:mat.id}}),0);assert.equal(await q.reportMutation.count({where:{key:k}}),0);
   await q.$executeRawUnsafe('DROP TRIGGER reject_history ON report_history');assert.equal((await create(mat.id,student,k)).status,201);
  });
  await t.test('actividad, rol vigente y revocación se comprueban también en replay',async()=>{
   await a.user.update({where:{id:users.student.id},data:{active:false}});assert.equal((await create(material.id,student,key)).status,403);await a.user.update({where:{id:users.student.id},data:{active:true,tokenVersion:1}});assert.equal((await http('/reports/me',student)).status,401);
   student=tokens.issue({...users.student,tokenVersion:1});assert.equal((await http('/reports/me',student)).status,200);
   await a.user.update({where:{id:users.moderator.id},data:{role:'STUDENT'}});assert.equal((await http('/moderation/reports',moderator)).status,403);await a.user.update({where:{id:users.moderator.id},data:{role:'MODERATOR'}});
  });
  await t.test('reporte legado sin autoría: oculto falla cerrado; público puede conciliarse',async()=>{
   const mat=await newMaterial(users.author.id,'WITHDRAWN');const legacy=await q.report.create({data:{materialId:mat.id,userId:users.student.id,reason:'OTHER'}});
   const r=(await http('/reports/'+legacy.id,student)).body;assert.equal((await patch(r,admin)).status,503);await m.material.update({where:{id:mat.id},data:{status:'PUBLISHED'}});assert.equal((await patch(r,author)).status,403);assert.equal((await patch(r,admin)).status,200);
  });
  await t.test('Material no disponible: nueva creación 503; replay sigue siendo histórico',async()=>{
   const mat=await newMaterial();await matApp.close();assert.equal((await create(mat.id,student)).status,503);assert.deepEqual((await create(material.id,student,key)).body,report);
  });
  await t.test('Auth no disponible: no concede lectura ni escritura',async()=>{
   await authApp.close();assert.equal((await http('/reports/me',student)).status,503);assert.equal((await create(material.id,student,key)).status,503);
  });
  await t.test('deploy repetido conserva datos y registros de idempotencia',async()=>{
   const before=await q.report.count();const c=configs[0];execFileSync(process.execPath,[require.resolve('prisma/build/index.js'),'migrate','deploy'],{cwd:resolve(root,'quality-service'),env:{...process.env,DATABASE_URL:c.url},stdio:'pipe'});assert.equal(await q.report.count(),before);assert.ok(await q.reportMutation.count());
  });
 }finally{
  for(const app of apps.reverse())await app.close();
  for(const client of clients){try{await client.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);}finally{await client.$disconnect();}}
  rmSync(dir,{recursive:true,force:true});for(const k of Object.keys(process.env))if(!(k in env))delete process.env[k];Object.assign(process.env,env);
 }
});
