export const verifyCaptchaURL = (userCaptchaToken: string, secretKey: string) => {
  return `https://www.google.com/recaptcha/api/siteverify?secret=${secretKey}&response=${userCaptchaToken}`;
};
