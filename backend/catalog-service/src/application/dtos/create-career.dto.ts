import {
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateCareerDto {
  @IsUUID()
  @IsNotEmpty()
  universityId!: string;

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
