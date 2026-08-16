import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_card.dart';

class JsonOutputPanel extends StatelessWidget {
  const JsonOutputPanel({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('JSON', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Copy to clipboard',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pretty));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied JSON to clipboard')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  pretty,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: scheme.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
