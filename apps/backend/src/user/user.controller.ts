import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { UserService } from './user.service';

@Controller()
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('user')
  postUser(@Body() userData: any) {
    // Implement user creation logic
    return {
      message: 'User creation stub',
      data: userData,
    };
  }

  @Get('user/:id')
  getUser(@Param('id') id: string) {
    // Fetch user by ID from database
    return {
      id,
      name: 'Vechain User',
      email: 'vechain@example.com',
    };
  }

  @Post('validate-claim')
  async validateClaim(@Body() claimData: any) {
    // Use our service implementation that integrates the mock AI and blockchain
    return this.userService.validateClaim(claimData);
  }
}
