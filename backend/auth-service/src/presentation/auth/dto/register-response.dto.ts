import { ApiProperty } from '@nestjs/swagger';
import { Role } from '../../../domain/auth/role.enum';

export class PublicUserDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ format: 'email' })
  email!: string;

  @ApiProperty({ enum: Role })
  role!: string;

  @ApiProperty()
  active!: boolean;
}

export class RegisterResponseDto {
  @ApiProperty({ type: PublicUserDto })
  user!: PublicUserDto;
}
