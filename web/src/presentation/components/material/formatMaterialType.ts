const TYPE_LABELS: Record<string, string> = {
  DOCUMENT: 'Documento / guía',
  PRESENTATION: 'Presentación',
  EXAM: 'Prueba',
  SUMMARY: 'Resumen',
  LINK: 'Enlace',
  GUIDE: 'Guía',
  CLASS_NOTES: 'Apuntes de clase',
  OTHER: 'Otro',
};

const EMPTY_VALUE = 'Por definir';

export function formatMaterialType(type?: string | null): string {
  if (!type) return EMPTY_VALUE;
  return TYPE_LABELS[type] ?? type;
}
