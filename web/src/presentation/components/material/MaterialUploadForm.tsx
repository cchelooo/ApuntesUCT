import React, { useState } from 'react';
import { Button } from '../Button';
import { Input } from '../Input';
import { Select } from '../Select';
import { Alert } from '../Alert';
import { Spinner } from '../Spinner';
import { mapMaterialError } from '../../../infrastructure/material/materialErrorHandler';
import {
  uploadMaterial as defaultUploadMaterial,
  type UploadMaterialPayload,
  type UploadMaterialResponse,
} from '../../../infrastructure/material/materialApi';

export interface MaterialUploadFormProps {
  onSuccess?: (response: UploadMaterialResponse) => void;
  onError?: (error: unknown) => void;
  uploadFn?: (
    payload: UploadMaterialPayload
  ) => Promise<UploadMaterialResponse>;
  className?: string;
}

const MATERIAL_TYPE_OPTIONS = [
  { value: 'DOCUMENT', label: 'Documento (PDF, Word)' },
  { value: 'PRESENTATION', label: 'Presentación (PowerPoint)' },
  { value: 'EXAM', label: 'Certamen / Examen' },
  { value: 'SUMMARY', label: 'Resumen' },
  { value: 'LINK', label: 'Enlace externo (Google Drive, YouTube)' },
];

export function MaterialUploadForm({
  onSuccess,
  onError,
  uploadFn = defaultUploadMaterial,
  className = '',
}: MaterialUploadFormProps) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [year, setYear] = useState(new Date().getFullYear().toString());
  const [type, setType] = useState('DOCUMENT');
  const [subjectId, setSubjectId] = useState('');
  const [careerId, setCareerId] = useState('');
  const [professorId, setProfessorId] = useState('');
  const [externalLink, setExternalLink] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);

  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const isLinkType = type === 'LINK';

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    setSelectedFile(file);
    setErrorMessage(null);
  };

  const handleRemoveFile = () => {
    setSelectedFile(null);
  };

  const resetForm = () => {
    setTitle('');
    setDescription('');
    setYear(new Date().getFullYear().toString());
    setType('DOCUMENT');
    setSubjectId('');
    setCareerId('');
    setProfessorId('');
    setExternalLink('');
    setSelectedFile(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);

    // Validación de metadatos básicos obligatorios
    if (!title.trim() || !year.trim() || !subjectId.trim()) {
      setErrorMessage('Por favor, completa todos los campos obligatorios.');
      return;
    }

    // Regla de negocio: LINK requiere enlace externo
    if (isLinkType) {
      if (!externalLink.trim()) {
        setErrorMessage(
          'Debes ingresar un enlace externo para este tipo de material.'
        );
        return;
      }
    } else {
      // DOCUMENT, PRESENTATION, EXAM, SUMMARY requieren archivo local
      if (!selectedFile) {
        setErrorMessage(
          'Debes seleccionar un archivo para subir este material.'
        );
        return;
      }
    }

    setIsLoading(true);

    try {
      const payload: UploadMaterialPayload = {
        title: title.trim(),
        description: description.trim() || undefined,
        year: year.trim(),
        type,
        subjectId: subjectId.trim(),
        careerId: careerId.trim() || undefined,
        professorId: professorId.trim() || undefined,
        externalLink: externalLink.trim() || undefined,
        file: selectedFile,
      };

      const response = await uploadFn(payload);

      setSuccessMessage('Material subido exitosamente.');
      resetForm();
      onSuccess?.(response);
    } catch (err: unknown) {
      const friendlyMessage = mapMaterialError(err);
      setErrorMessage(friendlyMessage);
      onError?.(err);
    } finally {
      setIsLoading(false);
    }
  };

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return `${bytes} B`;
    const kb = bytes / 1024;
    if (kb < 1024) return `${kb.toFixed(1)} KB`;
    return `${(kb / 1024).toFixed(1)} MB`;
  };

  return (
    <form
      noValidate
      onSubmit={handleSubmit}
      className={`bg-white rounded-xl shadow-sm border border-gray-200 p-6 sm:p-8 space-y-6 ${className}`.trim()}
      aria-label="Formulario de subida de material"
    >
      <div className="border-b border-gray-100 pb-4">
        <h2 className="text-xl font-bold text-gray-900">
          Subir Material Académico
        </h2>
        <p className="text-sm text-gray-500 mt-1">
          Comparte apuntes, guías y recursos con la comunidad estudiantil.
        </p>
      </div>

      {errorMessage && <Alert variant="error" message={errorMessage} />}
      {successMessage && <Alert variant="success" message={successMessage} />}

      <div className="space-y-4">
        <Input
          label="Título del material"
          id="material-title"
          name="title"
          placeholder="Ej: Guía Práctica de Álgebra Lineal"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isLoading}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Select
            label="Tipo de material"
            id="material-type"
            name="type"
            value={type}
            onChange={(e) => {
              setType(e.target.value);
              setErrorMessage(null);
            }}
            options={MATERIAL_TYPE_OPTIONS}
            disabled={isLoading}
          />

          <Input
            label="Año académico"
            id="material-year"
            name="year"
            placeholder="Ej: 2026"
            value={year}
            onChange={(e) => setYear(e.target.value)}
            disabled={isLoading}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Input
            label="Asignatura (ID o código)"
            id="material-subject"
            name="subjectId"
            placeholder="Ej: MAT-101"
            value={subjectId}
            onChange={(e) => setSubjectId(e.target.value)}
            disabled={isLoading}
          />

          <Input
            label="Carrera (opcional)"
            id="material-career"
            name="careerId"
            placeholder="Ej: INF-01"
            value={careerId}
            onChange={(e) => setCareerId(e.target.value)}
            disabled={isLoading}
          />
        </div>

        <Input
          label="Profesor (opcional)"
          id="material-professor"
          name="professorId"
          placeholder="Ej: prof_102"
          value={professorId}
          onChange={(e) => setProfessorId(e.target.value)}
          disabled={isLoading}
        />

        {isLinkType ? (
          <Input
            label="Enlace externo (Google Drive, YouTube, etc.)"
            id="material-external-link"
            name="externalLink"
            type="url"
            placeholder="https://drive.google.com/..."
            value={externalLink}
            onChange={(e) => setExternalLink(e.target.value)}
            disabled={isLoading}
          />
        ) : (
          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="material-file-input"
              className="text-sm font-medium text-gray-700"
            >
              Archivo del material
            </label>
            <input
              id="material-file-input"
              name="file"
              type="file"
              aria-label="Archivo"
              onChange={handleFileChange}
              disabled={isLoading}
              accept=".pdf,.doc,.docx,.ppt,.pptx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
              className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-uct-blue/10 file:text-uct-navy hover:file:bg-uct-blue/20 cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
            />
            {selectedFile ? (
              <div className="flex items-center justify-between text-xs bg-slate-50 border border-slate-200 rounded p-2 mt-1">
                <span className="font-medium text-gray-700 truncate max-w-xs">
                  {selectedFile.name} ({formatFileSize(selectedFile.size)})
                </span>
                <button
                  type="button"
                  onClick={handleRemoveFile}
                  disabled={isLoading}
                  className="text-red-500 hover:text-red-700 font-medium ml-2 cursor-pointer disabled:opacity-50"
                >
                  Quitar
                </button>
              </div>
            ) : (
              <span className="text-xs text-gray-500">
                Formatos permitidos: PDF, Word (.doc, .docx), PowerPoint (.ppt,
                .pptx). Máximo 15 MB.
              </span>
            )}
          </div>
        )}

        <div className="flex flex-col gap-1.5">
          <label
            htmlFor="material-description"
            className="text-sm font-medium text-gray-700"
          >
            Descripción (opcional)
          </label>
          <textarea
            id="material-description"
            name="description"
            rows={3}
            placeholder="Breve resumen del contenido del material..."
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            disabled={isLoading}
            className="block w-full rounded-md border border-gray-300 text-sm px-3 py-2 outline-hidden focus:border-uct-sky focus:ring-2 focus:ring-uct-sky transition-colors disabled:bg-gray-100 disabled:cursor-not-allowed"
          />
        </div>
      </div>

      <div className="pt-2">
        <Button
          type="submit"
          disabled={isLoading}
          className="w-full flex items-center justify-center gap-2"
        >
          {isLoading && <Spinner size="sm" className="text-white" />}
          {isLoading ? 'Subiendo material...' : 'Subir material'}
        </Button>
      </div>
    </form>
  );
}

export const MaterialForm = MaterialUploadForm;
export default MaterialUploadForm;
