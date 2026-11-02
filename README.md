# LoanTrack (Kadan Kanakku)

A private, offline-first Flutter app for tracking money lent and borrowed, monthly
interest, repayments, and personal savings. English and Tamil are supported.

App source: [`flutter_app/`](./flutter_app/)

## Features

- Loans given and taken, with interest-free or monthly-interest calculations.
- Accrued and overdue interest, principal and interest payments, settlement totals.
- Loan detail history, payment recording/deletion, and PDF statements.
- Savings records with search, type filtering, sorting, and targets.
- Dashboard totals, receivable/payable interest, next-due reminders, and reports.
- PIN or biometric app lock, with escalating lockout after failed PIN attempts.
- Due-date notifications; tapping a reminder opens that loan.
- Tamil / English, light / dark theme, and a privacy toggle for amounts.
- JSON backup to the clipboard, with validation when restoring.

## Privacy

- Loan, payment, savings, and app-lock data are stored in encrypted local storage.
  Profile, language, and theme preferences stay in local preferences.
- The app does not request internet permission and never sends data to a server.
- Android cloud/device backup is disabled for app data.
- Uninstalling the app or clearing storage removes local data; keep a JSON backup.

## Run and test

Requires the Flutter SDK, Android SDK, and JDK 17.

```powershell
cd "D:\Money MM\flutter_app"
flutter pub get
flutter analyze
flutter test
flutter run
```

The project path must not contain spaces on Windows when running tests, because the
native-assets test hook fails on such paths. Use a space-free path (for example
`D:\MoneyMM`) or a junction.

## APK build

```powershell
cd "D:\Money MM\flutter_app"
flutter build apk --release
```

APK: `flutter_app\build\app\outputs\flutter-apk\app-release.apk`

For smaller direct-download APKs:

```powershell
flutter build apk --release --split-per-abi
```

For production signing, copy `flutter_app/android/key.properties.example` to
`key.properties` and fill in the private upload-keystore values. Without that file
the build falls back to debug signing, which is suitable for sideloading only.
Play Store releases require an upload keystore and release signing configuration.

See [`flutter_app/AUDIT.md`](./flutter_app/AUDIT.md) for the security audit notes.
