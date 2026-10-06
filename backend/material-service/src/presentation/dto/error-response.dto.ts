import { ApiProperty } from '@nestjs/swagger';

export class ErrorResponseDto {
  @ApiProperty({ example: 400, description: 'Código de estado HTTP' })
  statusCode!: number;

  @ApiProperty({ example: 'Bad Request', description: 'Nombre corto del error HTTP' })
  error!: string;

  @ApiProperty({ 
    oneOf: [
      { type: 'string', example: 'El archivo supera el límite de 15 MB (15728640 bytes).' },
      { type: 'array', items: { type: 'string' }, example: ['year must match /^(19|20)\\d{2}$/'] }
    ],
    description: 'Mensaje descriptivo del error o lista de fallos de validación' 
  })
  message!: string | string[];

  @ApiProperty({ example: '2026-10-05T14:00:00.000Z', description: 'Marca de tiempo ISO del error' })
  timestamp!: string;

  @ApiProperty({ example: '/api/v1/materials', description: 'Ruta donde ocurrió el error' })
  path!: string;
}