import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { resolve } from 'node:path';
import configuration from './config/configuration';
import { QualityModule } from './quality.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: resolve(__dirname, '../.env'),
      load: [configuration],
    }),
    QualityModule,
  ],
})
export class AppModule {}
