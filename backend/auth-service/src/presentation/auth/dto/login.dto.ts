import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'estudiante@alu.uct.cl' })
  @IsEmail()
  email!: string;

  @ApiProperty({
    example: 'demo',
    description: 'El mock no verifica credenciales.',
  })
  @IsString()
  @IsNotEmpty()
  password!: string;
}
