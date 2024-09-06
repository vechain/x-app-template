import picasso from "@vechain/picasso";

export const getPicassoImgSrc = (address: string, base64 = false) => {
  const image = picasso(address.toLowerCase());
  if (base64) {
    const base64data = Buffer.from(image, "utf8").toString("base64");
    return `data:image/svg+xml;base64,${base64data}`;
  }
  return `data:image/svg+xml;utf8,${image}`;
};
