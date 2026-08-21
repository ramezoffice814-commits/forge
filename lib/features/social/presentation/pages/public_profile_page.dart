import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_empty_state.dart';
import '../../../../shared/widgets/forge_error_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/usecases/get_public_profile_usecase.dart';
import '../providers/social_providers.dart';

/// Renders exactly one [PublicProfile] — never anything from the target
/// user's raw progression/competition/mission state. A hidden profile
/// (visibility settings say no) renders a neutral "not visible" message,
/// never an error and never a hint at *why* beyond that.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(publicProfileProvider(userId));

    return ForgeScaffold(
      appBarTitle: 'Profile',
      body: result.when(
        loading: () =>
            const ForgeLoadingState(message: 'Loading this profile…'),
        error: (_, _) => const ForgeErrorState(
          message: "Couldn't load this profile right now.",
        ),
        data: (value) => switch (value) {
          PublicProfileAvailable(:final profile) => _ProfileContent(
            profile: profile,
          ),
          PublicProfileHidden() => const ForgeEmptyState(
            icon: Icons.lock_outline,
            title: 'This profile is private',
            message: "This user's profile isn't visible to you.",
          ),
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.space4),
      child: ForgeCard(
        elevation: ForgeCardElevation.md,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: tokens.neutralRamp.c800,
            child: Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          SizedBox(height: tokens.spacing.space3),
          Text(
            profile.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            profile.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.text.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: tokens.spacing.space3),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.space4,
            runSpacing: tokens.spacing.space2,
            children: [
              _Stat(label: 'Level', value: '${profile.level}'),
              _Stat(
                label: 'Achievements',
                value: '${profile.achievementsCount}',
              ),
              _Stat(label: 'League', value: profile.league),
            ],
          ),
          SizedBox(height: tokens.spacing.space3),
          Text(
            profile.competitionSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
