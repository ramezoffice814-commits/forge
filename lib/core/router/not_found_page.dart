import 'package:flutter/material.dart';

import '../../shared/widgets/forge_empty_state.dart';
import '../../shared/widgets/forge_scaffold.dart';

/// Fallback for any location that doesn't match a route
/// ([GoRouter.errorBuilder]).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return ForgeScaffold(
      appBarTitle: 'Not found',
      body: ForgeEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Page not found',
        message: message ?? "That route doesn't exist.",
      ),
    );
  }
}
