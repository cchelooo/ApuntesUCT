import { AccessContextController } from './access-context.controller';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
describe('Identidad actual para reportes',()=>{
 const findUnique=jest.fn(); const verify=jest.fn();
 const controller=new AccessContextController({verify} as unknown as AccessTokenService,{user:{findUnique}} as unknown as PrismaService);
 beforeEach(()=>{verify.mockReturnValue({sub:'u',role:'ADMIN',tokenVersion:0});findUnique.mockResolvedValue({id:'u',role:'STUDENT',active:true,tokenVersion:0});});
 test.each([undefined,'Basic abc','Bearer a b'])('rechaza header %s',async h=>expect(controller.get(h)).rejects.toMatchObject({status:401}));
 test('usa rol vigente, no el rol antiguo del token',async()=>expect(controller.get('Bearer signed')).resolves.toEqual({id:'u',role:'STUDENT',active:true}));
 test('revocación',async()=>{findUnique.mockResolvedValue({id:'u',role:'ADMIN',active:true,tokenVersion:1});await expect(controller.get('Bearer signed')).rejects.toMatchObject({status:401});});
 test('inactivo',async()=>{findUnique.mockResolvedValue({id:'u',role:'ADMIN',active:false,tokenVersion:0});await expect(controller.get('Bearer signed')).rejects.toMatchObject({status:403});});
 test('falla de BD no concede acceso',async()=>{findUnique.mockRejectedValue(Error('db'));await expect(controller.get('Bearer signed')).rejects.toMatchObject({status:503});});
 test('versión inválida',async()=>{verify.mockReturnValue({sub:'u',tokenVersion:'0'});await expect(controller.get('Bearer signed')).rejects.toMatchObject({status:401});});
});
