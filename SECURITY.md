# Security

## Reporting a problem

Please report security problems privately, not in a public issue: use GitHub's **Report a vulnerability** button on the
Security tab of this repository (private vulnerability reporting). If that is not available, open an issue that says only
that you have a security report and ask for a private way to send the details.

Useful details: which file and line, what an attacker could do, and the Windows version you saw it on.

## What this project does to protect people who run it

- The short-link launchers (`toolkit`, `ShortLinks/assess`) and `Install.ps1` run **published releases only**, and check their
  SHA-256 hash against `manifest.json` on the project website before running or copying anything. They stop if the check
  fails.
- The online mode works in a new, randomly named, administrators-only folder, refuses links and untrusted owners, and
  verifies that it deleted the folder.

## What it does not do

- It is not code-signed. The hash check protects against a changed download, not against a compromised release process, so
  the maintainer account should use two-factor authentication and protected branches and tags.
- The elevated copy of the `toolkit` and `assess` launchers fetches the launcher script itself again from the project website
  before it checks the release hash. The release payload is verified, but the small launcher is trusted as served by
  `jlesc2026.github.io`, so protecting the GitHub account and the Pages repository matters.
- It runs PowerShell with `-ExecutionPolicy Bypass` and, in online mode, with administrator rights. Endpoint security may
  flag this, and you should run it only on computers you are authorized to support.
- The online mode does not remove Windows' own records (event logs, PowerShell or process-creation logging, antivirus
  history, Prefetch, the DNS cache). See "Minimal footprint" in the README.

## Supported versions

Only the latest release is supported.
