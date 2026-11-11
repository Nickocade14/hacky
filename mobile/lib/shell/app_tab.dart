import 'package:flutter/material.dart';

/// The five pages of the signed-in app. Hacky (12) is where you land; the
/// header ([ShellHeader]) opens Chats 10, People 06, Home 05 and Me 08, and
/// the Ask Hacky button comes back to Hacky. Same layout as the web
/// (web/src/SignedInShell.tsx).
enum AppTab {
  home('Home', Icons.event_available_outlined),
  people('People', Icons.person_search_outlined),
  hacky('Hacky', Icons.auto_awesome_outlined),
  chats('Chats', Icons.chat_outlined),
  me('Me', Icons.person_outline);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
