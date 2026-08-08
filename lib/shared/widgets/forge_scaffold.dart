import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// The app's base page shell: themed background, an optional transparent
/// [AppBar], a [SafeArea]d body, and an optional bottom bar slot (used by
/// [AppShell] — https://pub.dev/packages/go_router `StatefulShellRoute`
/// convention: the outer shell owns the bottom nav, each tab's root page
/// owns its own [ForgeScaffold] with its own app bar).
class ForgeScaffold extends StatelessWidget {
  const ForgeScaffold({
    super.key,
    required this.body,
    this.appBarTitle,
    this.actions,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? appBarTitle;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: appBarTitle == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(appBarTitle!),
              actions: actions,
            ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
