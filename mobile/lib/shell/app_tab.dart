import 'package:flutter/material.dart';

/// The five tabs of the signed-in app, in tab bar order
/// (mobile/design/README.md): Home 05 · People 06 · Hacky 12 · Chats 10 · Me 08.
enum AppTab {
  home('Home', Icons.home_outlined, Icons.home),
  people('People', Icons.people_outline, Icons.people),
  hacky('Hacky', Icons.auto_awesome_outlined, Icons.auto_awesome),
  chats('Chats', Icons.chat_bubble_outline, Icons.chat_bubble),
  me('Me', Icons.person_outline, Icons.person);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
