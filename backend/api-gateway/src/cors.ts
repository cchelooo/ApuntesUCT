import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

// Configuración CORS compartida entre el arranque real (main.ts) y las pruebas de
// integración, para que ambas apliquen exactamente las mismas cabeceras expuestas.
export const corsOptions: CorsOptions = {
  exposedHeaders: ['Content-Disposition'],
};
