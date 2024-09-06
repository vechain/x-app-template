export const resizeImage = async (file: File) => {
  return new Promise((resolve) => {
    const img = document.createElement("img");
    const canvas = document.createElement("canvas");
    const reader = new FileReader();

    reader.onload = (e) => {
      img.onload = () => {
        let width = img.width;
        let height = img.height;
        const maxWidth = 1200; // Max width for the image
        const maxHeight = 1000; // Max height for the image
        if (width > height) {
          if (width > maxWidth) {
            height *= maxWidth / width;
            width = maxWidth;
          }
        } else {
          if (height > maxHeight) {
            width *= maxHeight / height;
            height = maxHeight;
          }
        }
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        ctx?.drawImage(img, 0, 0, width, height);
        ctx?.canvas.toBlob(
          (blob) => {
            resolve(blob);
          },
          file.type,
          0.7, // Adjust compression rate here
        );
      };
      // @ts-expect-error img src is a string
      img.src = e.target.result.toString();
    };
    reader.readAsDataURL(file);
  });
};

export const blobToBase64 = async (blob: Blob): Promise<string> =>
  new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.readAsDataURL(blob);
  });
