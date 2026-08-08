import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Reusable global "loading" state — a centered, accent-colored spinner
/// with an optional message. Used wherever a page/section is waiting on
/// data, regardless of feature.
class ForgeLoadingState extends StatelessWidget {
  const ForgeLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: tokens.accent),
            if (message != null) ...[
              SizedBox(height: tokens.spacing.space3),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
