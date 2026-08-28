import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/forge_motion.dart';
import '../../../core/theme/forge_tokens.dart';
import '../../../shared/widgets/forge_button.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import 'onboarding_status_notifier.dart';
import 'widgets/onboarding_page_template.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String kicker;
  final String title;
  final String body;
}

const _pages = [
  _OnboardingPageData(
    icon: Icons.bolt_rounded,
    kicker: 'PROVE YOU CAN',
    title: 'Daily discipline, compounding.',
    body:
        'One focused challenge a day — fitness and craft — building toward '
        'a 100-day streak.',
  ),
  _OnboardingPageData(
    icon: Icons.record_voice_over_outlined,
    kicker: 'DAILY TRANSMISSION',
    title: 'A mysterious voice briefs your mission.',
    body:
        "An original character announces each day's challenge — subtitles "
        'on by default, with a mute control always within reach.',
  ),
  _OnboardingPageData(
    icon: Icons.trending_up_rounded,
    kicker: 'FAIR BY DESIGN',
    title: 'Adaptive difficulty, recovery over punishment.',
    body:
        'Miss a day and Recovery Mode offers an achievable comeback '
        'mission instead of resetting everything — weekly leagues stay '
        'fair, every week.',
  ),
  _OnboardingPageData(
    icon: Icons.shield_outlined,
    kicker: 'YOUR DATA, YOUR CONTROL',
    title: 'Private by default.',
    body:
        'Your reflections and habits stay private unless you choose to '
        'share. Create an account to start your streak.',
  ),
];

/// The 3–4 screen first-run pitch. Skip and "finish the last page" both
/// mark onboarding complete (so it never shows again on this device) but
/// land differently: Skip goes to sign-in (neutral), finishing goes
/// straight to account creation, matching the last screen's own CTA.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo(String routeName) async {
    await ref.read(onboardingStatusProvider.notifier).markCompleted();
    if (mounted) context.goNamed(routeName);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _completeAndGo(AppRouteNames.signUp);
      return;
    }
    _pageController.animateToPage(
      _index + 1,
      duration: ForgeMotion.duration(
        context,
        const Duration(milliseconds: 300),
      ),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_index == 0) return;
    _pageController.animateToPage(
      _index - 1,
      duration: ForgeMotion.duration(
        context,
        const Duration(milliseconds: 300),
      ),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isLast = _index == _pages.length - 1;

    return ForgeScaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.space4,
              tokens.spacing.space4,
              tokens.spacing.space4,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _completeAndGo(AppRouteNames.signIn),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                for (final page in _pages)
                  OnboardingPageTemplate(
                    icon: page.icon,
                    kicker: page.kicker,
                    title: page.title,
                    body: page.body,
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tokens.spacing.space6),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: ForgeMotion.duration(
                            context,
                            const Duration(milliseconds: 250),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? tokens.accent
                                : tokens.neutralRamp.c700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacing.space4),
                Row(
                  children: [
                    if (_index > 0) ...[
                      Expanded(
                        child: ForgeButton(
                          label: 'Back',
                          variant: ForgeButtonVariant.secondary,
                          onPressed: _back,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.space3),
                    ],
                    Expanded(
                      child: ForgeButton(
                        label: isLast ? 'Create Account' : 'Next',
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
