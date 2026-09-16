import { IsArray, IsBoolean, IsEmail, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateProfessorDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsEmail()
  @IsNotEmpty()
  email!: string;

  @IsArray()
  @IsUUID('all', { each: true })
  @IsOptional()
  subjectIds?: string[];

  @IsBoolean()
  @IsOptional()
  active?: boolean;
}