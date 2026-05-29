/// ═══════════════════════════════════════════════════════════════════════════════
/// 🏛️ OWJ Assistant — Pillar Card Widget
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Pillar card widget showing name, score circle, color, icon,
/// and last updated timestamp. Supports compact and full modes.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/pillar.dart';

class PillarCard extends StatelessWidget {
  final PillarData pillar;
  final bool compact;
  final VoidCallback? onTap;

  const PillarCard({
    super.key,
    required this.pillar,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = _parseColor(pillar.colorHex);

    if (compact) {
      return _buildCompact(pillarColor);
    }
    return _buildFull(pillarColor);
  }

  /// Compact mode — used in the horizontal row on home screen.
  Widget _buildCompact(Color color) {
    return Material(
      color: OwjColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OwjColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Text(pillar.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),

              // Name
              Text(
                pillar.nameAr,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OwjColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Score circle (compact)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    pillar.score.toStringAsFixed(0),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full mode — used on the pillars screen.
  Widget _buildFull(Color color) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(pillar.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),

              const SizedBox(width: 16),

              // Name and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillar.nameAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: OwjColors.textPrimary,
                      ),
                    ),
                    Text(
                      pillar.type.descriptionAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: OwjColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Score circle
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        pillar.score.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'من 10',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return OwjColors.primary;
    }
  }
}
