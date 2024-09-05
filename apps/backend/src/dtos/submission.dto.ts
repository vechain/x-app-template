import { IsNotEmpty, IsString, Length } from 'class-validator';

export class SubmitDto {
  @IsString()
  @IsNotEmpty()
  public image: string;

  @IsString()
  @IsNotEmpty()
  @Length(42, 42) // 42 is the length of an Vechain address including the 0x prefix
  public address: string;

  @IsString()
  @IsNotEmpty()
  public deviceID: string;
}
