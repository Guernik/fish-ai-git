# Security Policy

These functions run on your machine and can update automatically via
`fisher update`. That makes trust a real question, and this document is meant to
answer it **honestly** — including where the guarantees stop.

## Reporting a vulnerability

Please report suspected vulnerabilities privately rather than opening a public
issue:

- Use GitHub's **[Report a vulnerability](../../security/advisories/new)**
  (Security → Advisories) to open a private advisory, **or**
- email **emilio.guernik@gmail.com** with details and, ideally, a proof of
  concept.

You'll get an acknowledgement as soon as possible. Please give a reasonable
window to fix before any public disclosure.

## What protects you — and what doesn't

There are two different threats, and they need two different kinds of defense.
Be clear-eyed about which is which.

### 1. A malicious or mistaken outside contributor

Defended by:

- **Required review + branch protection** (below): nothing reaches `main`
  without a reviewed pull request.
- **An automated audit** (`just audit`, run in CI on every PR) that scans the
  _shipped_ files for a tight set of obviously-dangerous shell patterns —
  piping the network into a shell (`curl … | sh`), `eval` on interpolated
  input, sourcing a downloaded file, decode-and-run obfuscation. The result is
  posted as a comment on the PR.

### 2. A malicious or compromised **maintainer**

**The audit script does _not_ protect you from this, and it can't.** Anyone who
can merge can also edit or delete that script in the same change. A repo owner
who wants to ship malicious code can bypass any check the owner controls.

What actually protects you here is **provenance you can verify yourself,
independent of the maintainer's good behavior**:

- **Pin to a signed release tag** instead of tracking `main` (below). A pushed
  tag is immutable and, when signed, cryptographically attributable.
- **Verify the tag's signature** against the published key before trusting a
  release (below).
- **Branch protection** means changes are at least _visible_ in public,
  reviewed PRs rather than silent force-pushes.

None of this removes your own responsibility to **audit the code you run**. It
just makes that audit tractable: review one immutable, signed version instead of
a moving branch.

## Install a pinned, verifiable version

By default `fisher install Guernik/fish-ai-git` tracks the tip of `main`, so
every merge lands on your machine at the next `fisher update`. To run only
immutable, tagged releases, pin with `@`:

```fish
fisher install Guernik/fish-ai-git@v1.0.0
```

Your pinned version is recorded in `~/.config/fish/fish_plugins`; you update
deliberately by bumping the tag, not automatically.

## Verify a release signature

Release tags are **signed with SSH**. To verify one yourself:

1. Save the project's signing key into an allowed-signers file. The key is:

   ```
   releases@fish-ai-git namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7UpIH1zIypmWr5xNltfNGSyXsN66EB6kB0gGpaeQMn releases@fish-ai-git
   ```

   Save that line (without the `#` comments) to e.g. `~/.fish-ai-git-signers`.
   The `namespaces="git"` field is required for `git tag -v` to accept it.

2. Point git at it and verify the tag:

   ```fish
   git config gpg.ssh.allowedSignersFile ~/.fish-ai-git-signers
   git clone https://github.com/Guernik/fish-ai-git
   cd fish-ai-git
   git tag -v v1.0.0
   ```

   A `Good "git" signature` line confirms the tag was signed by the published
   key. If verification fails or the tag is unsigned, **do not trust that
   release.**

> Build-provenance attestation for releases is planned as a future addition and
> will be documented here when available.

## Branch protection (what to expect on `main`)

So you can check these yourself in the repo's **Settings → Branches**, `main`
is configured to:

- require a pull request before merging, with at least one approving review;
- require the CI status checks (lint, test, audit) to pass;
- disallow force-pushes and branch deletion.

If any of these are ever _not_ true, that itself is a signal worth questioning.

## Scope

This policy covers the code shipped in this repository (`functions/`,
`conf.d/`, and the CI/release machinery). It does not cover the third-party
tools these functions invoke (`git`, `gh`, `claude`, `fisher`) — audit and
trust those through their own projects.
