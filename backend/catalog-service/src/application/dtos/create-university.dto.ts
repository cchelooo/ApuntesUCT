import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateUniversityDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;

  @IsBoolean()
  @IsOptional()
  active?: boolean;
}