import 'package:flutter/material.dart';

import '../widgets/legal_page_scaffold.dart';

/// Draft privacy disclosure (Roadmap Item 19 section 17) — describes
/// CAN's actual current technical data handling as accurately as this
/// codebase's own audit trail supports (see docs/RELEASE_READINESS.md),
/// deliberately NOT a finished, legally-binding policy: no claims about
/// jurisdiction, user rights under a specific law (GDPR/CCPA/etc.),
/// retention periods as a legal commitment, or data-processor
/// agreements are made here — those require actual legal review, and
/// inventing them would be worse than the honest "pending" state this
/// page states plainly. Wire real, approved text in by editing
/// [_sections] once legal review completes; do not rewrite its legal
/// meaning silently.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = [
    LegalSection(
      heading: 'What CAN stores about you',
      body:
          'An account (email and a display name you choose), your mission '
          'completions and the resulting XP/level/achievement history, '
          'your competition/league standing, your notification '
          'preferences, and any text you type into the AI Coach chat. '
          'Account data is stored in a managed Postgres database '
          '(Supabase); nothing is sold or shared with advertisers.',
    ),
    LegalSection(
      heading: 'AI Coach',
      body:
          'CAN currently uses only a deterministic mock AI provider — '
          'no message you send is transmitted to OpenAI, Google, '
          'Anthropic, or any other real AI company. If a real provider '
          'is ever connected, this page will be updated before that '
          'change ships, not after.',
    ),
    LegalSection(
      heading: 'What stays on your device',
      body:
          'Your session token, onboarding status, AI privacy choice, and '
          'local reminder history are stored in your device\'s secure '
          'keystore (Android Keystore / Windows Credential Manager / '
          'browser storage on Web), scoped to your account. Signing out '
          'or uninstalling the app removes this local copy; it never '
          'leaves your device.',
    ),
    LegalSection(
      heading: 'Notifications',
      body:
          'On Android and Windows, CAN can show device notifications '
          'for your own reminders (daily mission, daily transmission, '
          'mission follow-up) — nothing is sent through a third-party '
          'push service; these are scheduled and shown entirely on your '
          'device. You control this in Settings, and permission is only '
          'requested when you explicitly turn it on.',
    ),
    LegalSection(
      heading: 'Account deletion',
      body:
          'Account deletion is not implemented yet — requesting it in '
          'Settings currently returns an honest "not available yet" '
          'message rather than pretending to delete anything. This will '
          'be built out as its own reviewed feature before CAN is '
          'submitted to any app store.',
    ),
    LegalSection(
      heading: 'Third parties',
      body:
          'No analytics, advertising, or tracking SDK is integrated in '
          'this app today. The only third-party service in the request '
          'path is Supabase, which hosts the database and authentication '
          'backend on CAN\'s behalf.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalPageScaffold(
      title: 'Privacy',
      lastUpdated: 'Roadmap Item 19 — not yet legally reviewed',
      sections: _sections,
    );
  }
}
