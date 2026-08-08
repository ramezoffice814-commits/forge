import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_button.dart';

/// Full-transcript modal, reachable at any time regardless of audio state —
/// this is the accessible fallback for the entire dialogue. Uses the
/// standard [showModalBottomSheet] focus/dismiss behavior rather than a
/// custom overlay, so screen-reader focus handling stays correct for free.
Future<void> showTranscriptSheet(
  BuildContext context, {
  required String characterName,
  required String transcript,
}) {
  final tokens = Theme.of(context).extension<ForgeTokens>()!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$characterName — Transcript',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.space3),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    transcript,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.space3),
              ForgeButton(
                label: 'Close',
                variant: ForgeButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
