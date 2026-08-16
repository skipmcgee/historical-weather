import 'package:flutter/material.dart';

import 'aeolus_background.dart';

/// Shared page chrome: the drifting [AeolusBackground], a transparent
/// floating app bar with the Aeolus wind-glyph wordmark, and enough top
/// padding for content to clear it.
class AeolusScaffold extends StatelessWidget {
  const AeolusScaffold({super.key, required this.title, required this.body, this.actions});

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: _Wordmark(subtitle: title), actions: actions),
      body: Stack(
        children: [
          const Positioned.fill(child: AeolusBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight + 8),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.air, color: scheme.primary, size: 24),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AEOLUS',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
