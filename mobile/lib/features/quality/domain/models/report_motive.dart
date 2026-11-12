/// Motivos de reporte provisionales sujetos al contrato pendiente de la issue #444.
///
/// Nota de integración: Este componente implementa exclusivamente la capa de
/// presentación y validaciones locales. No se acredita integración en firme con
/// el microservicio Quality en este PR.
enum ReportMotive {
  outdated('OUTDATED', 'Desactualizado'),
  incorrect('INCORRECT', 'Incorrecto'),
  duplicate('DUPLICATE', 'Duplicado'),
  inappropriate('INAPPROPRIATE', 'Inapropiado'),
  defective('DEFECTIVE', 'Defectuoso o Enlace Roto');

  final String code;
  final String label;

  const ReportMotive(this.code, this.label);
}
