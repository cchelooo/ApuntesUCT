import React, { useId, useRef, useState } from 'react';
import { AcademicSelectors } from '../catalog/AcademicSelectors';
import type { AcademicSelection } from '../catalog/AcademicSelectors';
import { Button } from '../Button';
import { Input } from '../Input';
import { Select } from '../Select';
import { Alert } from '../Alert';
import { Spinner } from '../Spinner';
import { mapMaterialUploadError } from '../../../infrastructure/material/materialErrorHandler';
import {
  uploadMaterial,
  type MaterialTypeValue,
} from '../../../infrastructure/material/materialApi';
import './MaterialUploadForm.css';

export interface MaterialUploadFormProps {
  onSuccess?: (result?: unknown) => void;
  onError?: (error: unknown) => void;
  uploadFn?: (formData: FormData) => Promise<unknown>;
  accessToken?: string;
  className?: string;
}

const MATERIAL_TYPE_OPTIONS = [
  { value: 'DOCUMENT', label: 'Documento / guía' },
  { value: 'PRESENTATION', label: 'Presentación' },
  { value: 'EXAM', label: 'Evaluación' },
  { value: 'SUMMARY', label: 'Resumen' },
  { value: 'LINK', label: 'Enlace' },
];

const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024;

export function MaterialUploadForm({
  onSuccess,
  onError,
  uploadFn,
  accessToken,
  className = '',
}: MaterialUploadFormProps) {
  const id = useId();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const reviewHeading = useRef<HTMLHeadingElement>(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [year, setYear] = useState('');
  const [type, setType] = useState<MaterialTypeValue>('DOCUMENT');
  const [externalLink, setExternalLink] = useState('');
  const [file, setFile] = useState<File | null>(null);

  const [academic, setAcademic] = useState<AcademicSelection>({
    universityId: '',
    careerId: '',
    subjectId: '',
    professorId: '',
  });

  const [review, setReview] = useState<[string, string][] | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const isLinkType = type === 'LINK';
  const hasAcademicSelection = Boolean(
    academic.universityId && academic.careerId && academic.subjectId
  );

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0] ?? null;
    if (selectedFile && selectedFile.size > MAX_FILE_SIZE_BYTES) {
      setFile(null);
      setError(
        'El archivo supera el tamaño máximo permitido de 15 MB. Por favor, selecciona un archivo de menor tamaño.'
      );
      setSuccess(null);
      e.target.value = '';
      return;
    }
    setFile(selectedFile);
    setError(null);
    if (selectedFile) {
      setSuccess(null);
    }
  };

  const handleReview = (e?: React.FormEvent | React.MouseEvent) => {
    if (e) e.preventDefault();
    if (!hasAcademicSelection) {
      setError('Selecciona universidad, carrera y asignatura para continuar.');
      return;
    }

    const selectedLabel = (name: string, fallback = '') => {
      const select = document.querySelector(
        `select[name="${name}"]`
      ) as HTMLSelectElement | null;
      return select?.selectedOptions[0]?.textContent ?? fallback;
    };

    setReview([
      ['Título', title],
      ['Descripción', description || 'Sin descripción'],
      ['Universidad', selectedLabel('universityId')],
      ['Carrera', selectedLabel('careerId')],
      ['Asignatura', selectedLabel('subjectId')],
      [
        'Profesor',
        academic.professorId
          ? selectedLabel('professorId')
          : 'Sin profesor asociado',
      ],
      ['Año', year],
      [
        'Tipo',
        selectedLabel(
          'type',
          type === 'SUMMARY'
            ? 'Resumen'
            : type === 'DOCUMENT'
              ? 'Documento / guía'
              : type
        ),
      ],
      [
        isLinkType ? 'Enlace' : 'Archivo',
        isLinkType ? externalLink : (file?.name ?? ''),
      ],
    ]);

    requestAnimationFrame(() => reviewHeading.current?.focus());
  };

  const handleSubmit = async (e?: React.FormEvent | React.MouseEvent) => {
    if (e) e.preventDefault();

    // Protección crucial contra dobles envíos
    if (isUploading) return;

    setError(null);
    setSuccess(null);

    const activeSubjectId = academic.subjectId.trim();

    // Validación en cliente
    if (!title.trim()) {
      setError('Por favor, ingresa el título del material.');
      return;
    }
    if (!academic.universityId || !academic.careerId || !activeSubjectId) {
      setError('Selecciona universidad, carrera y asignatura para continuar.');
      return;
    }
    if (!year.trim()) {
      setError('Por favor, ingresa el año del material.');
      return;
    }
    if (isLinkType && !externalLink.trim()) {
      setError(
        'Debes ingresar un enlace externo válido para este tipo de material.'
      );
      return;
    }
    if (!isLinkType && !file) {
      setError('Debes seleccionar un archivo para subir.');
      return;
    }

    setIsUploading(true);

    try {
      const formData = new FormData();
      formData.append('title', title.trim());
      if (description.trim()) {
        formData.append('description', description.trim());
      }
      formData.append('year', year.trim());
      formData.append('type', type);
      formData.append('subjectId', activeSubjectId);
      formData.append('careerId', academic.careerId);
      if (academic.professorId) {
        formData.append('professorId', academic.professorId);
      }
      if (externalLink.trim()) {
        formData.append('externalLink', externalLink.trim());
      }
      if (file) {
        formData.append('file', file);
      }

      const result = uploadFn
        ? await uploadFn(formData)
        : await uploadMaterial(formData, { accessToken });

      // Confirmación de subida exitosa
      setError(null);
      setSuccess('¡Material subido exitosamente!');
      setTitle('');
      setDescription('');
      setExternalLink('');
      setFile(null);
      setReview(null);

      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }

      // Tratamiento aislado del callback onSuccess:
      // Si el material ya fue creado con éxito pero el callback posterior falla,
      // la confirmación de subida exitosa se conserva y se notifica el error por separado,
      // sin reemplazar el éxito por un error de subida ni mostrar mensajes simultáneos.
      try {
        await Promise.resolve(onSuccess?.(result));
      } catch (callbackErr: unknown) {
        onError?.(callbackErr);
      }
    } catch (err: unknown) {
      setSuccess(null);
      const errorMessage = mapMaterialUploadError(err);
      setError(errorMessage);
      onError?.(err);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        handleReview(e);
      }}
      noValidate
      aria-busy={isUploading}
      onChange={() => setReview(null)}
      className={`material-upload space-y-6 ${className}`.trim()}
      aria-label="Formulario de subida de material"
      data-testid="material-upload-form"
    >
      {/* Alerta de Error */}
      {error && (
        <Alert
          variant="error"
          message={error}
          className="my-2"
          data-testid="upload-error-alert"
        />
      )}

      {/* Alerta de Éxito */}
      {!error && success && (
        <Alert
          variant="success"
          message={success}
          className="my-2"
          data-testid="upload-success-alert"
        />
      )}

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
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            disabled={isUploading}
            data-testid="upload-title-input"
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
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              disabled={isUploading}
              data-testid="upload-description-input"
              placeholder="Cuenta qué incluye el material y cómo puede ayudar a estudiar."
              className="block w-full rounded-md border border-gray-300 p-2 text-sm text-gray-900 transition-colors focus:border-uct-sky focus:outline-hidden focus:ring-2 focus:ring-uct-sky disabled:bg-gray-100 disabled:cursor-not-allowed"
            />
          </div>
          <div className="grid min-w-0 gap-5 sm:grid-cols-2">
            <Input
              label="Año"
              name="year"
              required
              inputMode="numeric"
              value={year}
              onChange={(e) => setYear(e.target.value)}
              disabled={isUploading}
              data-testid="upload-year-input"
              placeholder="Ej. 2026"
              helperText="Año académico del material."
            />
            <Select
              label="Tipo de material"
              name="type"
              required
              options={MATERIAL_TYPE_OPTIONS}
              value={type}
              onChange={(event) => {
                const nextType = event.target.value as MaterialTypeValue;
                if ((nextType === 'LINK') !== isLinkType) {
                  setFile(null);
                  if (fileInputRef.current) fileInputRef.current.value = '';
                }
                setType(nextType);
              }}
              disabled={isUploading}
              data-testid="upload-type-select"
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
          {isLinkType ? 'Enlace del material' : 'Archivo del material'}
        </legend>
        {isLinkType ? (
          <Input
            label="Enlace"
            name="externalLink"
            type="url"
            required
            value={externalLink}
            onChange={(e) => setExternalLink(e.target.value)}
            disabled={isUploading}
            data-testid="upload-link-input"
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
              ref={fileInputRef}
              id={`${id}-file`}
              name="file"
              type="file"
              disabled={isUploading}
              data-testid="upload-file-input"
              accept=".pdf,.doc,.docx,.ppt,.pptx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
              aria-describedby={`${id}-file-help`}
              onChange={handleFileChange}
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
                  disabled={isUploading}
                  className="min-h-11 shrink-0"
                  onClick={() => {
                    setFile(null);
                    setReview(null);
                    if (fileInputRef.current) {
                      fileInputRef.current.value = '';
                      fileInputRef.current.focus();
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
          {!hasAcademicSelection
            ? 'Selecciona los datos académicos para continuar. '
            : ''}
          Puedes revisar tus datos antes de publicar o subir el material
          directamente.
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <Button
            type="submit"
            onClick={handleReview}
            disabled={!hasAcademicSelection}
            aria-describedby={`${id}-review-help`}
            className="min-h-12 w-full shrink-0 rounded-xl sm:w-auto"
          >
            Revisar material
          </Button>
          <Button
            type="button"
            onClick={handleSubmit}
            disabled={isUploading || !hasAcademicSelection}
            aria-busy={isUploading}
            data-testid="upload-submit-button"
            className="min-h-12 w-full shrink-0 rounded-xl sm:w-auto"
          >
            {isUploading ? (
              <span className="flex items-center gap-2">
                <Spinner size="sm" color="white" />
                Subiendo material...
              </span>
            ) : (
              'Subir material'
            )}
          </Button>
        </div>
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
            {review.map(([label, val]) => (
              <div key={label} className="min-w-0">
                <dt className="text-sm text-uct-muted">{label}</dt>
                <dd className="mt-1 whitespace-pre-wrap font-medium text-uct-navy [overflow-wrap:anywhere]">
                  {val}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
    </form>
  );
}
