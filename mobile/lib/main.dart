import 'package:flutter/material.dart';

import 'theme.dart';

void main() {
  runApp(const HackyApp());
}

class HackyApp extends StatelessWidget {
  const HackyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hacky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const PlaceholderHome(),
    );
  }
}

/// Temporary first screen until login / register is built.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'hacky.',
                  style: text.displaySmall?.copyWith(
                    color: AppColors.action,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Great things start with the right people.',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login and register are coming soon.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
