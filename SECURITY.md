# Security Policy

## Reporting a Vulnerability

If you believe you've found a security vulnerability in Forge, please
report it privately rather than opening a public issue.

**Contact:** `SECURITY-CONTACT-PLACEHOLDER@example.com`
*(placeholder — no security contact address has been configured for this
repository yet. Replace this with a real, monitored address before or
immediately after making the repository visible to anyone outside the
core team.)*

When reporting, please include:

- A description of the vulnerability and its potential impact.
- Steps to reproduce it (a minimal repro is ideal).
- The commit hash or version you tested against.

We'll acknowledge reports as quickly as possible and keep you updated as
the issue is investigated and, if confirmed, fixed.

## Please do not

- **Do not include real secrets, tokens, or credentials in a GitHub issue,
  pull request, or public discussion** — even to demonstrate a problem. If
  a report requires sharing a sensitive value, send it only through the
  private contact above, and mention in your report that a secret needs
  rotating so it isn't reused after disclosure.
- Do not test against production infrastructure or any account you don't
  own. As of this writing, Forge has no production backend at all — it
  runs entirely in a local mock mode by default (see the README's
  [Trust Boundaries](README.md#trust-boundaries) section) — so most
  security research applies to the client codebase itself (e.g. secure
  storage usage, dependency vulnerabilities) rather than a live service.

## Client trust model

Forge's client is intentionally treated as **untrusted** for anything
competitive or reward-bearing:

- XP, levels, and achievements computed on-device are explicitly marked
  provisional (`provisionalOnly`) and are never promoted to a confirmed
  value by any code in this repository.
- A future backend is expected to independently re-validate mission
  completions and progression events before granting anything real. That
  backend does not exist yet — there is currently no server component to
  attack, only the local mock logic.
- If you find a way to make the *client* report something implausible
  (e.g. XP exceeding its documented caps, an achievement unlocking without
  meeting its criteria), that's a legitimate finding worth reporting even
  though nothing server-side currently trusts the result — it's exactly
  the kind of bug that would matter once a backend does exist.

## Supported Versions

| Version | Supported |
|---|---|
| `main` (latest) | ✅ |
| Anything older | ❌ |

*(This project has not yet made a numbered release. This table is a
placeholder for once versioned releases exist.)*

## Responsible Disclosure

We ask that you give us a reasonable opportunity to investigate and address
a reported vulnerability before any public disclosure. We're not currently
running a bug bounty program.
