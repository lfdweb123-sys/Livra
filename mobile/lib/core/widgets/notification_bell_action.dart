import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bouton cloche notifications, à ajouter dans les `actions:` de l'AppBar
/// de chaque écran principal (la barre du bas n'a plus d'onglet dédié).
IconButton notificationBellAction(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.notifications_none_rounded),
    onPressed: () => context.push('/notifications'),
  );
}
