# LoanTrack app audit

Audit date: 2026-10-27

## Implemented in 1.3.0

- Added payment correction: an open loan's interest or principal payment can
  be deleted after confirmation, and all balances are recalculated.
- Preserved financial-history correctness when deleting a payment by removing
  a stale paid-period calculation snapshot only when no payment remains for
  that period.
- Upgraded JSON backup to version 3. It now includes loans, savings, profile,
  profile photo, language, theme and notification preference. PIN and biometric
  secrets are intentionally never exported.
- Added restore limits and duplicate-ID validation for loans, payments and
  savings, while retaining compatibility with old list/v2 backups.
- Added production keystore configuration support through
  `android/key.properties`; local builds safely retain the existing debug-key
  fallback until a private upload keystore is supplied.
- Ignored `.env.local` so local support/contact configuration is not committed.
- Added a model regression test for safe payment deletion.

## Verified strengths

- Core loan, monthly-interest, overdue, partial-payment and settlement logic
  has automated tests.
- Loan and savings records use Android Keystore-backed secure storage on a
  supported Android device.
- The app works without an Internet permission. Notifications, PDF generation,
  backup, calculations and storage are local.
- Android cloud backup and cleartext network traffic are disabled.
- PIN hashing uses a random salt and constant-time comparison; biometric unlock
  is available when supported by the device.
- Tamil/English, light/dark theme, amount privacy, savings, PDF/WhatsApp share,
  due reminders, analytics, profile and closed-loan history are present.

## Remaining release risks

1. A production upload keystore is still required before Play Store release.
   Never distribute a build signed with the debug fallback as a store release.
2. JSON backups contain readable financial and profile data. Keep them private;
   a future password-encrypted file backup is recommended.
3. Secure storage falls back to local preferences if a platform secure-storage
   service is unavailable. This is useful for unsupported/test environments but
   should be surfaced to users if it ever occurs on a production device.
4. Notification plugin behavior needs one real-device Android test because
   widget tests cannot initialize Android notification services.
5. The app currently stores the full dataset as JSON. For very large histories,
   migrate to a transactional local database with schema migrations.

## Recommended roadmap

### High priority

- Password-encrypted backup file export/import with a system file picker.
- Edit a payment in place with an audit trail, in addition to delete/re-add.
- Failed-PIN attempt throttling and a recovery flow that does not weaken local
  privacy.
- Signed Android App Bundle (`.aab`) and Play Console internal-track testing.

### Useful next features

- Customer-level statement covering multiple loans.
- Optional tags/categories and custom reminder lead times.
- CSV export for accountant/spreadsheet use.
- Dashboard actions that open the exact overdue account or upcoming due.
- Accessibility pass for text scaling, screen readers and color contrast.

## APK size

The universal APK contains native libraries for multiple CPU architectures.
Use `flutter build apk --release --split-per-abi` for smaller direct-download
APKs, or `flutter build appbundle --release` for Play Store delivery. PDF,
printing, biometric, notification and image-picker plugins are legitimate size
contributors and were not removed because they power active features.
