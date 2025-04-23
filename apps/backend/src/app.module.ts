import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { UserController } from './user/user.controller';
import { UserService } from './user/user.service';
import { AIService } from './ai/ai.service';
import { BlockchainService } from './blockchain/blockchain.service';
import { VeChainService } from './blockchain/vechain.service';

@Module({
  imports: [],
  controllers: [AppController, UserController],
  providers: [AppService, UserService, AIService, BlockchainService, VeChainService],
})
export class AppModule {}
