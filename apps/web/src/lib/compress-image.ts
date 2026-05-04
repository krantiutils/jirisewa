/**
 * Compress an image file using the Canvas API.
 * Resizes to maxDim and converts to JPEG at the given quality.
 */
export async function compressImage(
  file: File,
  maxSizeMB = 1,
  maxDim = 1200,
): Promise<File> {
  return new Promise((resolve) => {
    const img = new window.Image();
    img.onload = async () => {
      URL.revokeObjectURL(img.src);
      const canvas = document.createElement("canvas");
      let { width, height } = img;
      if (width > maxDim || height > maxDim) {
        const ratio = Math.min(maxDim / width, maxDim / height);
        width *= ratio;
        height *= ratio;
      }
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d")!;
      ctx.drawImage(img, 0, 0, width, height);
      const maxBytes = Math.max(0.1, maxSizeMB) * 1024 * 1024;
      let compressed: Blob | null = null;

      for (let quality = 0.82; quality >= 0.42; quality -= 0.08) {
        const blob = await new Promise<Blob | null>((done) => {
          canvas.toBlob(done, "image/jpeg", quality);
        });
        if (!blob) continue;
        compressed = blob;
        if (blob.size <= maxBytes) break;
      }

      if (!compressed) {
        resolve(file);
        return;
      }

      resolve(new File([compressed], file.name, { type: "image/jpeg" }));
    };
    img.onerror = () => {
      URL.revokeObjectURL(img.src);
      resolve(file); // fallback to original file
    };
    img.src = URL.createObjectURL(file);
  });
}
