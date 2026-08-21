import 'package:flutter/material.dart';

import '../../core/backend/backend_error_ux.dart';
import '../../core/theme/forge_tokens.dart';
import 'forge_button.dart';

/// A compact, inline banner for [BackendErrorUxState] (spec section 17)
/// — shown *within* a screen (an active mission, a reward card), never a
/// full-screen takeover like [ForgeErrorState]/[ForgeOfflineState],
/// since a sync issue is rarely the only thing on the page. Always uses
/// [defaultBackendErrorCopy] — never [BackendErrorUxState.message]
/// directly, so a server-originated string can never leak into the UI
/// verbatim (spec: "do not expose sequence internals, SQL details,
/// idempotency keys").
class SyncConflictBanner extends StatelessWidget {
  const SyncConflictBanner({super.key, required this.state, this.onRetry});

  final BackendErrorUxState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isConflict = state is SyncConflictUx;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.space4,
          vertical: tokens.spacing.space3,
        ),
        decoration: BoxDecoration(
          color: isConflict ? tokens.accent2Ramp.c800 : tokens.neutralRamp.c800,
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        child: Row(
          children: [
            Icon(
              isConflict
                  ? Icons.report_gmailerrorred_rounded
                  : Icons.sync_rounded,
              size: 20,
              color: isConflict
                  ? tokens.accent2Ramp.c100
                  : tokens.neutralRamp.c100,
            ),
            SizedBox(width: tokens.spacing.space3),
            Expanded(
              child: Text(
                defaultBackendErrorCopy(state),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isConflict
                      ? tokens.accent2Ramp.c100
                      : tokens.neutralRamp.c100,
                ),
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(width: tokens.spacing.space2),
              ForgeButton(
                label: 'Refresh',
                variant: ForgeButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
