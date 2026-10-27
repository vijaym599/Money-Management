# LoanTrack — Flutter Android app

தமிழ் / English ஆதரவுள்ள, இணையம் இல்லாமலும் இயங்கும் தனிப்பட்ட கடன், மாத வட்டி மற்றும் சேமிப்பு கணக்கு Android app.

App source: [`flutter_app/`](./flutter_app/)

## Offline மற்றும் privacy

- Loan, interest, principal payment, savings மற்றும் app-lock data secure local-storage flow-ல் சேமிக்கப்படும். Profile, language, theme preferences மட்டும் local preferences-ல் இருக்கும்.
- App இயங்க internet permission அல்லது server தேவையில்லை.
- Android cloud/device backup திட்டமிட்டு disable செய்யப்பட்டுள்ளது.
- JSON backup clipboard-க்கு copy செய்யலாம். அதில் நிதித் தகவல் இருப்பதால் பாதுகாப்பாக வைத்துக்கொள்ளவும்.
- App uninstall / Clear storage செய்தால் local data அழியும்; முன்பே JSON backup எடுக்கவும்.

## முக்கிய அம்சங்கள்

- கொடுத்த / வாங்கிய கடன்கள்
- மாத வட்டி மற்றும் முதல்தொகை செலுத்தல்கள்
- எல்லா பழைய மாதங்களின் மொத்த வட்டி நிலுவை
- பழைய நிலுவை மாதத்தை முதலில் செலுத்தும் workflow
- கடன் தேதியிலிருந்து ஒரு மாதம் முடிந்ததும் தானாக உருவாகும் வட்டி due date
- உள்ளூரில் மட்டும் சேமிக்கப்படும் profile photo மற்றும் profile தகவல்
- பெயர் தேடல் மற்றும் வகை filter
- Tamil / English, light / dark theme
- JSON backup மற்றும் restore validation
- சேமிப்பு இருக்கும் இடம், வகை, தொகை மற்றும் optional goal tracking
- App முழுவதும் தொகைகளை மறைக்கும் privacy toggle
- PIN / biometric app lock மற்றும் due-date notifications

## Run மற்றும் test

Flutter SDK, Android SDK, JDK 17 தேவை.

```powershell
cd "D:\Money MM\flutter_app"
flutter pub get
flutter analyze
flutter test
flutter run
```

சில Windows/Dart versions space உள்ள project path-ல் native-assets test hook-ஐ தவறாக இயக்கலாம். அப்படி ஏற்பட்டால் project-ஐ `D:\MoneyMM` போன்ற space இல்லாத path-க்கு மாற்றவும்.

## APK build

```powershell
cd "D:\Money MM\flutter_app"
flutter build apk --release
```

APK: `flutter_app\build\app\outputs\flutter-apk\app-release.apk`

இந்த project தற்போது தனிப்பட்ட sideload பயன்பாட்டிற்கு debug signing fallback பயன்படுத்துகிறது. Play Store release-க்கு தனிப்பட்ட upload keystore மற்றும் release signing configuration சேர்க்க வேண்டும்.
