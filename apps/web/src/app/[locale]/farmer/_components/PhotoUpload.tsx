"use client";

import { useState, useRef } from "react";
import Image from "next/image";
import { Upload, X, Loader2 } from "lucide-react";
import { uploadProducePhoto } from "../actions";

const MAX_PHOTOS = 5;

interface PhotoUploadProps {
  photos: string[];
  onChange: (photos: string[]) => void;
}

export function PhotoUpload({ photos, onChange }: PhotoUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    const remaining = MAX_PHOTOS - photos.length;
    if (remaining <= 0) {
      setError(`Maximum ${MAX_PHOTOS} photos allowed`);
      return;
    }

    setUploading(true);
    setError(null);

    const filesToUpload = Array.from(files).slice(0, remaining);
    const newUrls: string[] = [];

    for (const file of filesToUpload) {
      if (file.size > 1048576) {
        setError(`${file.name} is too large (max 1MB). Compress before uploading.`);
        continue;
      }

      const fd = new FormData();
      fd.append("file", file);

      const result = await uploadProducePhoto(fd);
      if (result.success) {
        newUrls.push(result.data.url);
      } else {
        setError(result.error);
      }
    }

    if (newUrls.length > 0) {
      onChange([...photos, ...newUrls]);
    }

    setUploading(false);

    // Reset input so same file can be selected again
    if (inputRef.current) {
      inputRef.current.value = "";
    }
  }

  function removePhoto(index: number) {
    const updated = photos.filter((_, i) => i !== index);
    onChange(updated);
  }

  return (
    <div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {photos.map((url, i) => (
          <div key={url} className="relative aspect-square overflow-hidden rounded-lg bg-muted">
            <Image
              src={url}
              alt={`Photo ${i + 1}`}
              fill
              className="object-cover"
            />
            <button
              type="button"
              onClick={() => removePhoto(i)}
              className="absolute right-1 top-1 rounded-full bg-red-500 p-1 text-white transition-transform hover:scale-110"
              aria-label="Remove photo"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        ))}

        {photos.length < MAX_PHOTOS && (
          <label className="flex aspect-square cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-300 bg-muted transition-colors hover:border-primary hover:bg-gray-50">
            {uploading ? (
              <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
            ) : (
              <>
                <Upload className="h-8 w-8 text-gray-400" />
                <span className="text-xs text-gray-500">
                  {photos.length}/{MAX_PHOTOS}
                </span>
              </>
            )}
            <input
              ref={inputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp"
              multiple
              onChange={handleFileChange}
              disabled={uploading}
              className="sr-only"
            />
          </label>
        )}
      </div>

      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
    </div>
  );
}
