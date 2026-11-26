import { useEffect, useState } from 'react';
import { Alert } from '../Alert';
import { Button } from '../Button';

interface PdfPreviewProps {
  previewUrl?: string | null;
  downloadUrl?: string | null;
  title?: string;
}

export function PdfPreview({
  previewUrl,
  downloadUrl,
  title = 'Previsualización del material',
}: PdfPreviewProps) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    let createdUrl: string | null = null;

    if (!previewUrl) return;

    void fetch(previewUrl)
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        const blob = await response.blob();
        createdUrl = URL.createObjectURL(blob);
        if (active) setObjectUrl(createdUrl);
      })
      .catch((caught) => {
        if (active) {
          setObjectUrl(null);
          setError(
            caught instanceof Error && /HTTP (403|404|401)/.test(caught.message)
              ? 'La previsualización no está disponible por permisos o acceso al archivo.'
              : 'No fue posible cargar la previsualización del PDF.'
          );
        }
      });

    return () => {
      active = false;
      if (createdUrl) URL.revokeObjectURL(createdUrl);
    };
  }, [previewUrl]);

  const isLoading = Boolean(previewUrl) && !objectUrl && !error;

  return (
    <section aria-label={title}>
      {isLoading && <p role="status">Cargando previsualización…</p>}
      {error && <Alert variant="error" message={error} />}
      {objectUrl && (
        <iframe title={title} src={objectUrl} className="h-[36rem] w-full" />
      )}
      {(error || (!isLoading && !objectUrl)) &&
        (downloadUrl ? (
          <a
            href={downloadUrl}
            className="inline-flex rounded-xs border px-4 py-2"
          >
            Descargar PDF
          </a>
        ) : (
          <Button type="button" disabled>
            Descargar PDF
          </Button>
        ))}
    </section>
  );
}
