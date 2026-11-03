import { useId, useRef, useState } from 'react';
import { useCreateMaterialVersionMutation } from '../../../application/material/useMaterialQueries';
import { mapMaterialError } from '../../../infrastructure/material/materialErrorHandler';
import { Alert } from '../Alert';
import { Button } from '../Button';

export function MaterialVersionUpload({ materialId }: { materialId: string }) {
  const inputId = useId();
  const fileInput = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [validation, setValidation] = useState<string | null>(null);
  const submitting = useRef(false);
  const mutation = useCreateMaterialVersionMutation(materialId);

  return (
    <div className="flex flex-col gap-3">
      <Button
        type="button"
        disabled={mutation.isPending}
        onClick={() => {
          setOpen(!open);
          mutation.reset();
          setValidation(null);
          setFile(null);
        }}
      >
        Subir nueva versión
      </Button>
      {mutation.isSuccess && (
        <Alert
          variant="success"
          message="Nueva versión subida correctamente."
        />
      )}
      {open && (
        <form
          className="flex flex-col gap-3"
          aria-busy={mutation.isPending}
          onSubmit={async (event) => {
            event.preventDefault();
            if (submitting.current) return;
            let error: string | null = null;
            if (!file) error = 'Selecciona un archivo.';
            else if (!file.size) error = 'El archivo está vacío.';
            else if (file.size > 15 * 1024 * 1024)
              error = 'El archivo supera el límite de 15 MiB.';
            else if (!/\.(pdf|docx?|pptx?)$/i.test(file.name))
              error =
                'Formato no permitido. Selecciona PDF, Word (.doc, .docx) o PowerPoint (.ppt, .pptx).';
            setValidation(error);
            if (error || !file) return;
            submitting.current = true;
            try {
              await mutation.mutateAsync(file);
              setOpen(false);
              setFile(null);
            } catch {
              // La mutación conserva el error para mostrarlo debajo del formulario.
            } finally {
              submitting.current = false;
            }
          }}
        >
          <p className="text-sm text-catalog-ink/70">
            Disponible para pruebas locales. Solo el autor puede subir
            versiones; el servidor verifica el permiso.
          </p>
          <label htmlFor={inputId}>Archivo de la nueva versión</label>
          <div className="flex min-w-0 flex-col gap-3 rounded-md border border-dashed border-catalog-line bg-catalog-paper p-4">
            <input
              ref={fileInput}
              id={inputId}
              type="file"
              accept=".pdf,.doc,.docx,.ppt,.pptx"
              disabled={mutation.isPending}
              onChange={(event) => {
                setFile(event.target.files?.[0] ?? null);
                setValidation(null);
                mutation.reset();
              }}
              className="sr-only"
              tabIndex={-1}
            />
            <Button
              type="button"
              variant="secondary"
              disabled={mutation.isPending}
              onClick={() => fileInput.current?.click()}
              aria-describedby={`${inputId}-selection`}
              className="w-full"
            >
              {file ? 'Cambiar archivo' : 'Seleccionar archivo'}
            </Button>
            <p
              id={`${inputId}-selection`}
              role="status"
              className="min-w-0 break-words text-sm text-catalog-ink/70 [overflow-wrap:anywhere]"
            >
              {file ? file.name : 'Ningún archivo seleccionado'}
            </p>
          </div>
          <p className="text-xs">
            PDF, Word o PowerPoint. Máximo 15 MiB. El servidor valida el
            contenido del archivo.
          </p>
          {validation && <Alert variant="error" message={validation} />}
          {mutation.isError && (
            <Alert
              variant="error"
              message={mapMaterialError(mutation.error, 'version')}
            />
          )}
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? 'Subiendo…' : 'Confirmar subida'}
          </Button>
          <Button
            type="button"
            variant="secondary"
            disabled={mutation.isPending}
            onClick={() => setOpen(false)}
          >
            Cancelar
          </Button>
        </form>
      )}
    </div>
  );
}
