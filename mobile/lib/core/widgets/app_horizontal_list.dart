import 'package:flutter/material.dart';

/// Lista horizontal reutilizable para cursos, materiales y colecciones.
///
/// Usa un constructor por índice para no construir elementos fuera del área
/// visible y mantiene el espaciado lateral de las pantallas principales.
class AppHorizontalList extends StatelessWidget {
  const AppHorizontalList({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.semanticLabel,
    super.key,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final list = SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => SizedBox(width: spacing),
      ),
    );

    if (semanticLabel == null) return list;

    return Semantics(container: true, label: semanticLabel, child: list);
  }
}
