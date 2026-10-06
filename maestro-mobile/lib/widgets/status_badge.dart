import 'package:flutter/material.dart';

import '../theme/maestro_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone});

  final String label;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final resolvedTone = tone ?? _toneFor(label);
    final colors = switch (resolvedTone) {
      StatusTone.success => (
          MaestroColors.successBg,
          MaestroColors.successText
        ),
      StatusTone.warning => (
          MaestroColors.warningBg,
          MaestroColors.warningText
        ),
      StatusTone.danger => (MaestroColors.dangerBg, MaestroColors.dangerText),
      StatusTone.neutral => (MaestroColors.neutralBg, const Color(0xFF374151)),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          _format(label),
          style: TextStyle(
            color: colors.$2,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  StatusTone _toneFor(String value) {
    return switch (value.toUpperCase()) {
      'PRESENT' || 'PAID' || 'ACTIVE' => StatusTone.success,
      'PENDING' || 'NOTHING' => StatusTone.warning,
      'ABSENT' || 'DISMISSED' || 'LATE' => StatusTone.danger,
      _ => StatusTone.neutral,
    };
  }

  String _format(String value) {
    return value.replaceAll('_', ' ').toUpperCase();
  }
}

enum StatusTone { success, warning, danger, neutral }
