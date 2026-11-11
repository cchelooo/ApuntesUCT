import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsString, Length, Matches, MaxLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'Camila Soto', minLength: 3, maxLength: 100 })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(3, 100)
  name!: string;

  @ApiProperty({ example: 'camila@alu.uct.cl', maxLength: 254 })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  @Matches(/^[^@\s]+@(uct\.cl|alu\.uct\.cl)$/, {
    message: 'email debe pertenecer a @uct.cl o @alu.uct.cl',
  })
  email!: string;

  @ApiProperty({ minLength: 8, maxLength: 128, writeOnly: true })
  @IsString()
  @Length(8, 128)
  @Matches(/\S/, { message: 'password no puede contener solo espacios' })
  password!: string;
}
