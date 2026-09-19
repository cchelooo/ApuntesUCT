import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Matches } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'estudiante@alu.uct.cl' })
  @IsEmail()
  email!: string;

  @ApiProperty({
    example: 'demo',
    description:
      'Debe contener al menos un carácter que no sea espacio en blanco. El mock no verifica credenciales.',
  })
  @IsString()
  @IsNotEmpty()
  @Matches(/\S/, {
    message:
      'password debe contener al menos un carácter que no sea espacio en blanco',
  })
  password!: string;
}
