import { isBase64 } from 'class-validator';

export const isBase64Image = (image: string): boolean => {
  const regex = /^data:image\/[a-z]+;base64,/;
  return regex.test(image) && isBase64(image.split(',')[1]);
};
