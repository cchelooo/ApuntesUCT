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
