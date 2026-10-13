import React, { useState } from 'react';
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

export interface MaterialUploadFormProps {
  onSuccess?: (result?: unknown) => void;
  onError?: (error: unknown) => void;
  uploadFn?: (formData: FormData) => Promise<unknown>;
  initialSubjectId?: string;
  className?: string;
}

const MATERIAL_TYPE_OPTIONS = [
  { value: 'DOCUMENT', label: 'Documento (apuntes, guías, textos)' },
  { value: 'PRESENTATION', label: 'Presentación (diapositivas)' },
  { value: 'EXAM', label: 'Examen / Certamen / Control' },
  { value: 'SUMMARY', label: 'Resumen o síntesis' },
  { value: 'LINK', label: 'Enlace externo (grabación, recursos externos)' },
];

export function MaterialUploadForm({
  onSuccess,
  onError,
  uploadFn,
  initialSubjectId = '',
  className = '',
}: MaterialUploadFormProps) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [year, setYear] = useState('2026');
  const [type, setType] = useState<MaterialTypeValue>('DOCUMENT');
  const [subjectId, setSubjectId] = useState(initialSubjectId);
  const [careerId, setCareerId] = useState('');
  const [professorId, setProfessorId] = useState('');
  const [externalLink, setExternalLink] = useState('');
  const [file, setFile] = useState<File | null>(null);

  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const isLinkType = type === 'LINK';

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0] ?? null;
    setFile(selectedFile);
    setError(null);
    setSuccess(null);
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    // Protección crucial contra dobles envíos
    if (isUploading) return;

    setError(null);
    setSuccess(null);

    // Validación en cliente
    if (!title.trim()) {
      setError('Por favor, ingresa el título del material.');
      return;
    }
    if (!subjectId.trim()) {
      setError('Por favor, ingresa el identificador de la asignatura.');
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
      formData.append('subjectId', subjectId.trim());
      if (careerId.trim()) {
        formData.append('careerId', careerId.trim());
      }
      if (professorId.trim()) {
        formData.append('professorId', professorId.trim());
      }
      if (externalLink.trim()) {
        formData.append('externalLink', externalLink.trim());
      }
      if (file) {
        formData.append('file', file);
      }

      const result = uploadFn
        ? await uploadFn(formData)
        : await uploadMaterial(formData);

      setSuccess('¡Material subido exitosamente!');
      setTitle('');
      setDescription('');
      setExternalLink('');
      setFile(null);

      const fileInput = document.getElementById(
        'material-file-input'
      ) as HTMLInputElement | null;
      if (fileInput) fileInput.value = '';

      onSuccess?.(result);
    } catch (err: unknown) {
      const errorMessage = mapMaterialUploadError(err);
      setError(errorMessage);
      onError?.(err);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      noValidate
      aria-busy={isUploading}
      className={`space-y-4 rounded-lg border border-catalog-line bg-catalog-paper p-6 shadow-xs ${className}`.trim()}
      aria-label="Formulario de subida de material"
      data-testid="material-upload-form"
    >
      <header>
        <h2 className="font-display text-xl font-bold text-catalog-ink">
          Subir Material Académico
        </h2>
        <p className="text-xs text-catalog-ink/70">
          Comparte documentos de estudio con tu comunidad universitaria.
        </p>
      </header>

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
      {success && (
        <Alert
          variant="success"
          message={success}
          className="my-2"
          data-testid="upload-success-alert"
        />
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Input
          label="Título *"
          placeholder="Ej: Resumen Certamen 1 Cálculo II"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isUploading}
          required
          data-testid="upload-title-input"
        />

        <Input
          label="Año *"
          placeholder="2026"
          value={year}
          onChange={(e) => setYear(e.target.value)}
          disabled={isUploading}
          required
          data-testid="upload-year-input"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Select
          label="Tipo de Material *"
          options={MATERIAL_TYPE_OPTIONS}
          value={type}
          onChange={(e) => setType(e.target.value as MaterialTypeValue)}
          disabled={isUploading}
          data-testid="upload-type-select"
        />

        <Input
          label="Identificador de Asignatura *"
          placeholder="Ej: INF-101"
          value={subjectId}
          onChange={(e) => setSubjectId(e.target.value)}
          disabled={isUploading}
          required
          data-testid="upload-subject-input"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Input
          label="Carrera (opcional)"
          placeholder="Ej: Ingeniería Civil Informática"
          value={careerId}
          onChange={(e) => setCareerId(e.target.value)}
          disabled={isUploading}
          data-testid="upload-career-input"
        />

        <Input
          label="Profesor (opcional)"
          placeholder="Ej: prof_102"
          value={professorId}
          onChange={(e) => setProfessorId(e.target.value)}
          disabled={isUploading}
          data-testid="upload-professor-input"
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label
          htmlFor="upload-description-input"
          className="text-sm font-medium text-gray-700"
        >
          Descripción (opcional)
        </label>
        <textarea
          id="upload-description-input"
          data-testid="upload-description-input"
          placeholder="Breve descripción o contenido del apunte..."
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          disabled={isUploading}
          rows={3}
          className="block w-full rounded-md border border-gray-300 p-2 text-sm text-gray-900 transition-colors focus:border-uct-sky focus:outline-hidden focus:ring-2 focus:ring-uct-sky disabled:bg-gray-100 disabled:cursor-not-allowed"
        />
      </div>

      {isLinkType ? (
        <Input
          label="Enlace Externo *"
          placeholder="https://drive.google.com/..."
          value={externalLink}
          onChange={(e) => setExternalLink(e.target.value)}
          disabled={isUploading}
          required
          data-testid="upload-link-input"
          helperText="Enlace a recurso o video externo (YouTube, Google Drive, OneDrive)."
        />
      ) : (
        <div className="flex flex-col gap-1.5">
          <label
            htmlFor="material-file-input"
            className="text-sm font-medium text-gray-700"
          >
            Archivo Académico *
          </label>
          <input
            id="material-file-input"
            data-testid="upload-file-input"
            type="file"
            onChange={handleFileChange}
            disabled={isUploading}
            accept=".pdf,.doc,.docx,.ppt,.pptx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
            className="block w-full rounded-md border border-gray-300 p-2 text-sm text-gray-700 file:mr-4 file:rounded-md file:border-0 file:bg-uct-blue file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white hover:file:bg-uct-blueDark disabled:bg-gray-100 disabled:cursor-not-allowed"
          />
          <p className="text-xs text-gray-500" id="upload-file-help">
            Formatos admitidos: <strong>PDF, Word (.doc, .docx)</strong> y{' '}
            <strong>PowerPoint (.ppt, .pptx)</strong>. Límite máximo:{' '}
            <strong>15 MB</strong>.
          </p>
          {file && (
            <p className="text-xs text-catalog-ink font-medium">
              Archivo seleccionado: {file.name} (
              {(file.size / (1024 * 1024)).toFixed(2)} MB)
            </p>
          )}
        </div>
      )}

      {/* Botón de envío con control de estados y prevención de dobles envíos */}
      <div className="pt-2 flex items-center justify-end gap-3">
        <Button
          type="submit"
          disabled={isUploading}
          aria-busy={isUploading}
          data-testid="upload-submit-button"
          className="w-full sm:w-auto"
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
    </form>
  );
}
