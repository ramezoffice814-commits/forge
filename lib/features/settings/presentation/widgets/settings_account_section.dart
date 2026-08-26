import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../auth/domain/auth_failure.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../../auth/presentation/auth_usecase_providers.dart';

/// Account identity, sign-out, and delete-account — the three account-
/// level controls Roadmap Item 16 asks Settings to own. There was
/// previously no sign-out control anywhere in the app at all; this is
/// the first real UI wired to the existing (already-implemented)
/// `SignOutUseCase`.
///
/// Delete-account is wired to the real, already-existing
/// [deleteAccountRequestUseCaseProvider] rather than hidden or faked —
/// every [AuthRepository] implementation of `requestAccountDeletion()`
/// unconditionally throws `ForgeAuthException(NotSupportedYetFailure())`
/// (see that use case's own doc comment: "exists so the call site and
/// its eventual UI can be wired up now without pretending deletion
/// actually works"), so tapping it can never destroy anything — it
/// always surfaces the honest "not available yet" message below.
class SettingsAccountSection extends ConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final session = ref.watch(authStateNotifierProvider).session;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account', style: textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space2),
        if (session != null) ...[
          Text(session.user.displayName, style: textTheme.bodyMedium),
          SizedBox(height: tokens.spacing.space1 / 2),
          Text(
            session.user.email,
            style: textTheme.bodySmall?.copyWith(
              color: tokens.text.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: tokens.spacing.space3),
        ],
        // Same reasoning as `AiPrivacySettingsTile`/`NotificationSettingsTile`:
        // `ForgeCard`'s own background is a plain `DecoratedBox`, not a
        // `Material` — without this, `ListTile`'s ink/selection painting
        // has no real Material ancestor to target and Flutter flags it.
        Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () => _confirmAndSignOut(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _confirmAndRequestDeletion(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to sign in again to continue your streak.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(authStateNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't sign out — please try again.")),
      );
    }
  }

  Future<void> _confirmAndRequestDeletion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your account and progress. This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var message = 'Account deletion is not available yet.';
    try {
      await ref.read(deleteAccountRequestUseCaseProvider).call();
      // Never actually reached today — every implementation throws
      // NotSupportedYetFailure — but handled honestly rather than
      // assumed, so this stays correct once a real backend exists.
      message = 'Your deletion request has been submitted.';
    } on ForgeAuthException catch (e) {
      if (e.failure is! NotSupportedYetFailure) {
        message = "Couldn't process that request — please try again.";
      }
    } catch (_) {
      message = "Couldn't process that request — please try again.";
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
