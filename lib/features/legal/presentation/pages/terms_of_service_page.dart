import 'package:flutter/material.dart';

import '../widgets/legal_page_scaffold.dart';

/// Draft Terms of Service placeholder (Roadmap Item 19 section 17).
/// Deliberately much shorter than [PrivacyPolicyPage] — a real Terms
/// document makes legal commitments (liability limits, dispute
/// resolution, governing law, acceptable use, age requirements) that
/// this codebase has no authority to invent. Structure and section
/// names are provided so legal review has a concrete checklist to fill
/// in, not prose asserting terms nobody has actually agreed to.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const _sections = [
    LegalSection(
      heading: 'Status',
      body:
          'CAN does not yet have reviewed, approved Terms of Service. '
          'This page exists so the route/surface is real ahead of '
          'launch, not to assert terms nobody has agreed to. Do not '
          'treat anything below as binding.',
    ),
    LegalSection(
      heading: 'Sections pending legal authorship',
      body:
          'Acceptable use, account eligibility/age requirements, '
          'termination, liability limitations, dispute resolution and '
          'governing law, intellectual property, and changes to these '
          'terms all still need real legal drafting before this page is '
          'anything more than a placeholder.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalPageScaffold(
      title: 'Terms of Service',
      lastUpdated: 'Roadmap Item 19 — not yet legally reviewed',
      sections: _sections,
    );
  }
}
