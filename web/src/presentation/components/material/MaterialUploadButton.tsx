import React, { useState, useRef } from 'react';
import { Button } from '../Button';
import { Alert } from '../Alert';
import { Spinner } from '../Spinner';
import { mapMaterialUploadError } from '../../../infrastructure/material/materialErrorHandler';
import { uploadMaterial } from '../../../infrastructure/material/materialApi';

export interface MaterialUploadButtonProps {
  onSuccess?: (result?: unknown) => void;
  onError?: (error: unknown) => void;
  uploadFn?: (file: File) => Promise<unknown>;
  subjectId?: string;
  title?: string;
  year?: string;
  type?: 'DOCUMENT' | 'PRESENTATION' | 'EXAM' | 'SUMMARY';
  disabled?: boolean;
  className?: string;
}

function UploadIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="mr-2 h-4 w-4"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      aria-hidden="true"
    >
      <path d="M10 14V5m0 0-3.5 3.5M10 5l3.5 3.5M4 16h12" />
    </svg>
  );
}

export function MaterialUploadButton({
  onSuccess,
  onError,
  uploadFn,
  subjectId = 'default-subject',
  title,
  year = '2026',
  type = 'DOCUMENT',
  disabled = false,
  className = '',
}: MaterialUploadButtonProps) {
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = async (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (isUploading) return; // Prevenir doble envío

    setIsUploading(true);
    setError(null);
    setSuccess(null);

    try {
      let result: unknown;
      if (uploadFn) {
        result = await uploadFn(file);
      } else {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('title', title || file.name);
        formData.append('year', year);
        formData.append('type', type);
        formData.append('subjectId', subjectId);
        result = await uploadMaterial(formData);
      }

      setError(null);
      setSuccess('¡Material subido exitosamente!');

      // Callback onSuccess separado para evitar mostrar éxito y error de manera simultánea
      // si el callback falla posteriormente a la creación del material.
      try {
        onSuccess?.(result);
      } catch (callbackErr: unknown) {
        setSuccess(null);
        const errorMsg = mapMaterialUploadError(callbackErr);
        setError(errorMsg);
        onError?.(callbackErr);
      }
    } catch (err: unknown) {
      setSuccess(null);
      const errorMsg = mapMaterialUploadError(err);
      setError(errorMsg);
      onError?.(err);
    } finally {
      setIsUploading(false);
      // Limpieza o reseteo del selector tanto en éxito como en error
      // para permitir volver a seleccionar el mismo archivo si se desea.
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleButtonClick = () => {
    if (isUploading || disabled) return;
    fileInputRef.current?.click();
  };

  return (
    <div className={`flex flex-col gap-2 ${className}`.trim()}>
      {error && (
        <Alert
          variant="error"
          message={error}
          data-testid="upload-button-error-alert"
        />
      )}
      {!error && success && (
        <Alert
          variant="success"
          message={success}
          data-testid="upload-button-success-alert"
        />
      )}
      <input
        type="file"
        ref={fileInputRef}
        onChange={handleFileChange}
        className="hidden"
        data-testid="file-upload-input"
        accept=".pdf,.doc,.docx,.ppt,.pptx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
      />
      <Button
        type="button"
        onClick={handleButtonClick}
        disabled={isUploading || disabled}
        aria-busy={isUploading}
        className="w-full"
        data-testid="material-upload-button"
      >
        {isUploading ? (
          <span className="flex items-center gap-2">
            <Spinner size="sm" color="white" />
            Subiendo material...
          </span>
        ) : (
          <>
            <UploadIcon />
            {error ? 'Reintentar subida' : 'Subir material'}
          </>
        )}
      </Button>
    </div>
  );
}
