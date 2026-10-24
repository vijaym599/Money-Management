# Security audit report

Audit date: 2026-10-25 (Asia/Calcutta)

Scope: repository working tree, all Git-tracked files, all reachable commits, Flutter/Dart source, Android configuration, dependency manifests, generated/release-file handling, Git hooks, and GitHub Actions. Bundled Flutter SDK/tooling internals and generated build caches are third-party/generated material and were excluded from source review; their presence and ignore status were checked.

No complete secret values are included in this report.

## Findings

### High: Android release build uses debug signing

`flutter_app/android/app/build.gradle.kts` assigns the debug signing configuration to release builds. Debug-signed production artifacts do not provide an appropriate production trust/update boundary.

Required action before a production release: create a protected release keystore outside Git, load its path/passwords from ignored local configuration or CI secrets, and configure release signing. This audit does not generate keys or change signing because credential creation and release identity require owner-controlled decisions.

### Medium: secure storage falls back to plaintext preferences

`SecureDataStore` falls back to `SharedPreferences` when encrypted storage is unavailable. That preserves availability, but can leave loan data and PIN-derived material in plaintext application preferences on affected devices/platforms.

Recommended action: fail closed for loan/PIN writes on supported production platforms, provide explicit migration/error UX, and remove legacy plaintext only after verified encrypted persistence. This needs product testing because it changes data-availability behavior.

### Medium: customer financial data can enter clipboard/notifications

JSON backup copies full loan records to the system clipboard, and reminder notifications include a customer name and amount. Clipboard readers, notification previews, device backups/screenshots, or user sharing can expose personal financial data.

Recommended action: add an explicit warning/confirmation, clear clipboard data where platform support permits, provide encrypted export, and offer privacy-safe notification text. These are user-visible behavior changes and require product approval/testing.

### Medium: PIN derivation is fast SHA-256

The app uses a random salt and constant-time comparison, but a short numeric PIN hashed once with SHA-256 is inexpensive to brute-force if the stored hash becomes available.

Recommended action: prefer a hardware-backed authentication/key-gating design, or use a deliberately slow password KDF with rate limiting. Migration must preserve existing users and be tested before release.

### Informational: no server-side secret integration found

The current application is local-first and contains no API endpoint, server credential, cloud service account, database connection string, or deployment secret. No application code was changed for environment-variable loading because doing so would add unused behavior. `.env.example` records that no environment variables are currently required.

### Informational: tracked/history secret indicators

No sensitive filename is currently tracked, and none appeared in reachable history during the redacted filename and indicator scans. Gitleaks verification status is recorded below and must remain part of every commit/push and CI run.

## Files present locally but not tracked

- Three generated APK release artifacts are ignored at repository root.
- The bundled Flutter SDK, local tooling, editor state, Dart/Gradle caches, build output, generated wrappers, and Android `local.properties` are ignored.
- These files were not deleted. Generated APKs can contain compiled application data and must not be treated as a secure secret store or attached publicly without release review.

## Manual verification checklist

- [ ] Review `git status --short` and `git diff --cached --name-status`; every staged path is intentional.
- [ ] Review staged content without posting secrets to logs or chat.
- [ ] Confirm `.env`, signing files, keys/certificates, databases/backups, logs, APK/AAB files, and customer exports are ignored and untracked.
- [ ] Run the exact-staged-patch Gitleaks command in `SECURITY.md`.
- [ ] Run `gitleaks git . --config .gitleaks.toml --redact --no-banner` across reachable history.
- [ ] Run Flutter static analysis and tests.
- [ ] Review dependency advisories/outdated packages and Android build/signing configuration.
- [ ] Confirm `git config --local --get core.hooksPath` returns `.githooks`.
- [ ] Confirm GitHub Actions passes on the branch/PR; organization-owned repositories may require a `GITLEAKS_LICENSE` repository/organization secret for the official action.
- [ ] If any credential was ever committed, rotate/revoke it before approved history cleanup.
- [ ] Do not use `--no-verify`; do not push or rewrite history without explicit approval.

## Verification status

This section is updated from the actual commands run during the audit handoff.

- Repository/working-tree redacted indicator scan: PASS
- Tracked sensitive filename scan: PASS
- Reachable-history sensitive filename/indicator scan: PASS
- Gitleaks working tree/history scan: NOT TESTED (binary was not installed at initial inventory)
- Git hook behavior: NOT TESTED
- Flutter static analysis: NOT TESTED
- Flutter unit/widget tests: NOT TESTED
- Dependency vulnerability/advisory scan: NOT TESTED
- Android production signing: NEEDS REVIEW
- Runtime storage/privacy findings: NEEDS REVIEW
