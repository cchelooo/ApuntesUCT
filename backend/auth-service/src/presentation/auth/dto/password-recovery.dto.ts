import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsString, Length, Matches, MaxLength } from 'class-validator';

export class ForgotPasswordDto {
  @ApiProperty({ example: 'camila@alu.uct.cl', maxLength: 254 })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class ResetPasswordDto {
  @ApiProperty({ writeOnly: true, minLength: 64, maxLength: 64 })
  @IsString()
  @Matches(/^[a-f0-9]{64}$/)
  token!: string;

  @ApiProperty({ writeOnly: true, minLength: 8, maxLength: 128 })
  @IsString()
  @Length(8, 128)
  @Matches(/\S/, { message: 'password no puede contener solo espacios' })
  password!: string;
}
