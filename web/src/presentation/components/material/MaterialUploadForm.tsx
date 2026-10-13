import { useId, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { AcademicSelectors } from '../catalog/AcademicSelectors';
import type { AcademicSelection } from '../catalog/AcademicSelectors';
import { Button } from '../Button';
import { Input } from '../Input';
import { Select } from '../Select';
import './MaterialUploadForm.css';

// Opciones de presentación del contrato CreateMaterialDto. La validación de
// tamaño, MIME, año y relaciones académicas sigue perteneciendo al backend.
const materialTypes = [
  { value: 'DOCUMENT', label: 'Documento / guía' },
  { value: 'PRESENTATION', label: 'Presentación' },
  { value: 'EXAM', label: 'Evaluación' },
  { value: 'SUMMARY', label: 'Resumen' },
  { value: 'LINK', label: 'Enlace' },
];

export function MaterialUploadForm() {
  const id = useId();
  const fileInput = useRef<HTMLInputElement>(null);
  const reviewHeading = useRef<HTMLHeadingElement>(null);
  const [academic, setAcademic] = useState<AcademicSelection>({
    universityId: '',
    careerId: '',
    subjectId: '',
    professorId: '',
  });
  const [type, setType] = useState('DOCUMENT');
  const [file, setFile] = useState<File | null>(null);
  const [review, setReview] = useState<[string, string][] | null>(null);
  const isLink = type === 'LINK';

  function handleReview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!academic.subjectId) return;
    const form = event.currentTarget;
    const data = new FormData(form);
    const text = (name: string) => String(data.get(name) ?? '');
    const selectedLabel = (name: string) => {
      const select = form.elements.namedItem(name) as HTMLSelectElement;
      return select.selectedOptions[0]?.textContent ?? '';
    };
    setReview([
      ['Título', text('title')],
      ['Descripción', text('description') || 'Sin descripción'],
      ['Universidad', selectedLabel('universityId')],
      ['Carrera', selectedLabel('careerId')],
      ['Asignatura', selectedLabel('subjectId')],
      [
        'Profesor',
        academic.professorId
          ? selectedLabel('professorId')
          : 'Sin profesor asociado',
      ],
      ['Año', text('year')],
      ['Tipo', selectedLabel('type')],
      [
        isLink ? 'Enlace' : 'Archivo',
        isLink ? text('externalLink') : (file?.name ?? ''),
      ],
    ]);
    // El resumen se monta antes de mover el foco para teclado y lector de pantalla.
    requestAnimationFrame(() => reviewHeading.current?.focus());
  }

  return (
    <form
      className="material-upload min-w-0 space-y-6"
      onSubmit={handleReview}
      onChange={() => setReview(null)}
    >
      <fieldset className="upload-section">
        <legend>
          <span aria-hidden="true">01</span> Información del material
        </legend>
        <p className="mb-6 text-sm text-uct-muted">
          Un buen título ayuda a que otros encuentren tu aporte.
        </p>
        <div className="space-y-5">
          <Input
            label="Título"
            name="title"
            required
            placeholder="Ej. Guía de integrales resueltas · Unidad 2"
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <label
              htmlFor={`${id}-description`}
              className="text-sm font-medium text-uct-navy"
            >
              Descripción{' '}
              <span className="font-normal text-uct-muted">(opcional)</span>
            </label>
            <textarea
              id={`${id}-description`}
              name="description"
              rows={4}
              placeholder="Cuenta qué incluye el material y cómo puede ayudar a estudiar."
            />
          </div>
          <div className="grid min-w-0 gap-5 sm:grid-cols-2">
            <Input
              label="Año"
              name="year"
              required
              inputMode="numeric"
              placeholder="Ej. 2026"
              helperText="Año académico del material."
            />
            <Select
              label="Tipo de material"
              name="type"
              required
              options={materialTypes}
              value={type}
              onChange={(event) => {
                const nextType = event.target.value;
                if ((nextType === 'LINK') !== isLink) setFile(null);
                setType(nextType);
              }}
            />
          </div>
        </div>
      </fieldset>

      <fieldset className="upload-section">
        <legend>
          <span aria-hidden="true">02</span> Datos académicos
        </legend>
        <p className="mb-4 text-sm text-uct-muted">
          Elige la universidad, la carrera y la asignatura a la que pertenece.
        </p>
        <AcademicSelectors
          required
          showHeading={false}
          value={academic}
          onChange={setAcademic}
        />
      </fieldset>

      <fieldset className="upload-section">
        <legend>
          <span aria-hidden="true">03</span>{' '}
          {isLink ? 'Enlace del material' : 'Archivo del material'}
        </legend>
        {isLink ? (
          <Input
            label="Enlace"
            name="externalLink"
            type="url"
            required
            placeholder="https://…"
            helperText="Comparte un enlace web al material y comprueba que otras personas puedan abrirlo."
          />
        ) : (
          <div className="rounded-2xl border-2 border-dashed border-uct-border bg-uct-mist p-5 text-center sm:p-8">
            <svg
              aria-hidden="true"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className="mx-auto mb-3 size-10 text-uct-blue"
            >
              <path
                d="M12 16V3m-5 5 5-5 5 5M4 15v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <label
              htmlFor={`${id}-file`}
              className="mb-2 block font-semibold text-uct-navy"
            >
              Selecciona tu archivo
            </label>
            <p id={`${id}-file-help`} className="mb-5 text-sm text-uct-muted">
              PDF, Word o PowerPoint · Máximo 15 MB
            </p>
            <input
              ref={fileInput}
              id={`${id}-file`}
              name="file"
              type="file"
              required
              accept=".pdf,.doc,.docx,.ppt,.pptx"
              aria-describedby={`${id}-file-help`}
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
            />
            {file && (
              <div
                className="mt-4 flex min-w-0 flex-wrap items-center justify-center gap-3"
                role="status"
              >
                <p className="min-w-0 text-sm text-uct-navy [overflow-wrap:anywhere]">
                  {file.name}{' '}
                  <span className="text-uct-muted">
                    (
                    {(file.size / 1024 / 1024).toLocaleString('es-CL', {
                      maximumFractionDigits: 2,
                    })}{' '}
                    MB)
                  </span>
                </p>
                <Button
                  type="button"
                  variant="ghost"
                  className="min-h-11 shrink-0"
                  onClick={() => {
                    setFile(null);
                    setReview(null);
                    if (fileInput.current) {
                      fileInput.current.value = '';
                      fileInput.current.focus();
                    }
                  }}
                >
                  Quitar archivo
                </Button>
              </div>
            )}
          </div>
        )}
      </fieldset>

      <div className="flex flex-col gap-4 rounded-2xl border border-uct-border bg-white p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6">
        <p
          id={`${id}-review-help`}
          className="max-w-md text-sm leading-relaxed text-uct-muted"
        >
          {!academic.subjectId
            ? 'Selecciona los datos académicos para continuar. '
            : ''}
          Puedes revisar tus datos antes de publicar. La publicación estará
          disponible próximamente.
        </p>
        <Button
          type="submit"
          disabled={!academic.subjectId}
          aria-describedby={`${id}-review-help`}
          className="min-h-12 w-full shrink-0 rounded-xl sm:w-auto"
        >
          Revisar material
        </Button>
      </div>

      {review && (
        <section
          aria-labelledby={`${id}-review`}
          className="rounded-2xl border border-uct-border bg-catalog-paperMuted p-5 sm:p-8"
        >
          <h2
            id={`${id}-review`}
            ref={reviewHeading}
            tabIndex={-1}
            className="text-xl font-semibold text-uct-blueDark focus:outline-hidden"
          >
            Revisa tu material
          </h2>
          <p className="mt-2 text-sm text-uct-muted" role="status">
            El material aún no se ha publicado ni guardado. Puedes editar los
            campos de arriba.
          </p>
          <dl className="mt-6 grid min-w-0 gap-5 sm:grid-cols-2">
            {review.map(([label, value]) => (
              <div key={label} className="min-w-0">
                <dt className="text-sm text-uct-muted">{label}</dt>
                <dd className="mt-1 whitespace-pre-wrap font-medium text-uct-navy [overflow-wrap:anywhere]">
                  {value}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
    </form>
  );
}
