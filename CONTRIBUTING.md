# Contributing to Kright

Thanks for your interest in improving Kright! This is a small, privacy-focused
keyboard utility, and contributions are welcome — please read this first so your
time isn't wasted.

## How contributions work

The `main` branch is protected. **Only the maintainer can push to it**, and every
change lands through a reviewed pull request:

1. **Open an issue first** for anything non-trivial (a bug or a feature). It lets
   us agree on the approach before you write code. Small fixes (typos, obvious
   bugs) can skip straight to a PR.
2. **Fork** the repo and create a branch (`fix/…` or `feature/…`).
3. Make your change, keeping it focused — one logical change per PR.
4. **Open a pull request** against `main`. It will sit until the maintainer
   reviews and approves it; **1 approval is required to merge**, and outside
   contributors can't merge their own PRs.

## The two apps (no shared code)

Each platform is a separate native app — there is **no cross-platform code**, so
a change usually touches only one side:

| Platform | Stack | Folder |
|----------|-------|--------|
| macOS    | Swift + SwiftUI | [`Mac/`](Mac/) |
| Windows  | C# + WPF (.NET 8) | [`Windows/`](Windows/) |

If you change shared *behavior* (e.g. the conversion logic), please mirror it on
both platforms in separate PRs, or note in your PR that the other side still
needs it.

## Building & testing

See the **For developers** section of the [README](README.md) for full build
steps. In short:

```sh
# macOS (needs Xcode + XcodeGen)
cd Mac && xcodegen generate && xcodebuild -scheme Kright -configuration Debug build
xcodebuild test -project Kright.xcodeproj -scheme Kright -destination 'platform=macOS'
```
```powershell
# Windows (needs .NET 8 SDK; the WPF app only builds on Windows)
cd Windows && dotnet build
dotnet test Tests/Kright.Tests.csproj
```

**Run the tests for the platform you touched** and make sure they pass before
opening a PR. New logic should come with a unit test where practical (the
conversion / detection code is pure and easy to test).

## Code style

- **Match the surrounding code** — naming, comment density, and idioms. Read the
  nearby file before adding to it.
- Keep comments about *why*, not *what*.
- No new third-party dependencies without discussing it in an issue first.

## Privacy is a hard requirement 🔒

Kright's core promise is **zero network, nothing stored, and secure/password
fields are never read**. Any contribution must uphold this:

- **No network calls** of any kind, except the existing signed auto-update check.
- **Never log, store, or transmit** what the user types.
- **Never read secure / password fields** — respect the existing blind-mode
  guards.

PRs that weaken these guarantees will not be merged.

## Security issues

Please **do not** open a public issue for a security vulnerability. Instead,
report it privately to the maintainer (see the repository owner's profile).

## Don't commit

Build output, signing keys, and local-only files are git-ignored — never commit
anything under `secrets/`, `*-PRIVATE.key`, or build/publish folders. Public
signing keys and appcasts are intentionally tracked.
