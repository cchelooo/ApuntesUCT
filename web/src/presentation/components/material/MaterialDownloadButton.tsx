import { Button } from '../Button';

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
  if (url) {
    return (
      <a
        href={url}
        download
        className="inline-flex w-full items-center justify-center rounded-md bg-catalog-maroon px-4 py-2 text-base font-medium text-white transition-colors hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-catalog-maroon focus:ring-offset-2"
      >
        <DownloadIcon />
        Descargar material
      </a>
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
