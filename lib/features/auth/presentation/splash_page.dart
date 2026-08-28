import 'package:flutter/material.dart';

import '../../../core/theme/forge_tokens.dart';
import '../../../shared/widgets/forge_loading_state.dart';
import '../../../shared/widgets/forge_scaffold.dart';

/// Shown only while [AuthStateNotifier] is restoring a session and the
/// onboarding-completion flag is loading — the router's redirect policy
/// bounces away as soon as both resolve, so this rarely stays on screen
/// for long.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ForgeScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CAN', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spacing.space4),
            const ForgeLoadingState(),
          ],
        ),
      ),
    );
  }
}
