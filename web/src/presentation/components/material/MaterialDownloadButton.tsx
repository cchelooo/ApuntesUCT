import { useState } from 'react';
import { Button } from '../Button';
import { Alert } from '../Alert';
import { mapMaterialError } from '../../../infrastructure/material/materialErrorHandler';

interface MaterialDownloadButtonProps {
  url?: string | null;
}

function DownloadIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="mr-2 h-4 w-4"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      aria-hidden="true"
    >
      <path d="M10 3v9m0 0-3.5-3.5M10 12l3.5-3.5M4 16h12" />
    </svg>
  );
}

export function MaterialDownloadButton({ url }: MaterialDownloadButtonProps) {
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleDownload = async () => {
    if (!url) return;

    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(url);

      if (!response.ok) {
        setError(mapMaterialError({ status: response.status }));
        return;
      }

      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;

      // Try to extract filename from Content-Disposition header if available
      const disposition = response.headers.get('Content-Disposition');
      let filename = 'material';
      if (disposition && disposition.indexOf('attachment') !== -1) {
        const filenameRegex = /filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/;
        const matches = filenameRegex.exec(disposition);
        if (matches != null && matches[1]) {
          filename = matches[1].replace(/['"]/g, '');
        }
      }

      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(downloadUrl);
    } catch (err) {
      setError(mapMaterialError(err));
    } finally {
      setIsLoading(false);
    }
  };

  if (url) {
    return (
      <div className="flex flex-col gap-2">
        {error && <Alert variant="error" message={error} />}
        <Button
          type="button"
          onClick={handleDownload}
          disabled={isLoading}
          className="w-full"
        >
          <DownloadIcon />
          {isLoading
            ? 'Descargando...'
            : error
              ? 'Reintentar descarga'
              : 'Descargar material'}
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <Button
        type="button"
        disabled
        aria-describedby="material-download-hint"
        className="w-full"
      >
        <DownloadIcon />
        Descargar material
      </Button>
      <p id="material-download-hint" className="text-xs text-catalog-ink/50">
        La descarga estará disponible cuando el material esté conectado.
      </p>
    </div>
  );
}
