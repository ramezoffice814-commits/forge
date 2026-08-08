import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_empty_state.dart';
import '../../domain/entities/hall_of_fame_record.dart';

/// Historical records only — display-only, never an input to current
/// ranking (spec section 22).
class HallOfFameList extends StatelessWidget {
  const HallOfFameList({super.key, required this.records});

  final List<HallOfFameRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const ForgeEmptyState(
        title: 'No records yet',
        message: 'Hall of Fame records appear once a season completes.',
      );
    }

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in records) ...[
          ForgeCard(
            children: [
              Text(
                record.displayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                record.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.space2),
        ],
      ],
    );
  }
}
