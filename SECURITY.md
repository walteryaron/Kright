# Security Policy

## Supported versions

Kright is distributed for macOS and Windows. Only the **latest release** receives
security fixes — please update before reporting (the app auto-updates once you
opt in).

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately instead, in either of these ways:

- **GitHub:** open a private advisory at
  [Security → Report a vulnerability](https://github.com/walteryaron/Kright/security/advisories/new)
- **Email:** walter@walterapps.com

Please include:
- affected platform (macOS / Windows) and Kright version,
- a description of the issue and its impact,
- steps to reproduce (a proof of concept if you have one).

**Do not include any passwords or sensitive text** in your report.

## What to expect

- An acknowledgement within a few days.
- An assessment and, if confirmed, a fix in the next release.
- Credit in the release notes if you'd like it (let us know).

## Scope

Kright is, by design, **offline**: it makes no network requests other than its
signed auto-update check, stores nothing the user types, and never reads
secure/password fields. Reports that demonstrate a break in any of these
guarantees — or in the update-signature verification (EdDSA on macOS, Ed25519 on
Windows) — are especially valuable.
