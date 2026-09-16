import 'package:flutter/material.dart';

/// Destinos principales disponibles en la navegación inferior de la app.
enum AppNavigationDestination { home, search, library, profile }

/// Barra de navegación inferior compartida por las pantallas principales.
///
/// Centraliza destinos, iconos, etiquetas y semántica mediante el
/// [NavigationBar] de Material. La pantalla que la consume decide cómo navegar
/// al recibir [onDestinationSelected], por lo que este widget no queda acoplado
/// a una implementación concreta de rutas.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.selectedDestination,
    required this.onDestinationSelected,
    super.key,
  });

  final AppNavigationDestination selectedDestination;
  final ValueChanged<AppNavigationDestination> onDestinationSelected;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: 'Buscar',
    ),
    NavigationDestination(
      icon: Icon(Icons.bookmark_border_rounded),
      selectedIcon: Icon(Icons.bookmark_rounded),
      label: 'Guardados',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigationDestination.values;

    return NavigationBar(
      selectedIndex: destinations.indexOf(selectedDestination),
      onDestinationSelected: (index) =>
          onDestinationSelected(destinations[index]),
      destinations: _destinations,
    );
  }
}
