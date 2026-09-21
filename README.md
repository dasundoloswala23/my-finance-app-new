# My Finance

A personal finance tracker built with Flutter and Firebase.

## Application identity

| | |
|---|---|
| Display name | My Finance |
| Android application ID | `com.dasun.myfinance` |
| iOS bundle identifier | `com.dasun.myfinance` |
| Dart package name | `myfinance` |
| Firebase project | `myfinance-e51e9` |

## Getting started

```bash
flutter pub get
flutter run
```

## Release build

Signing credentials live in `android/key.properties`, which is not tracked in version
control. It must point at the release keystore:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=key0
storeFile=C:\\KeyStore\\My Finance\\myfinance.jks
```

Then:

```bash
flutter build appbundle --release
```

If `android/key.properties` is missing, the release build falls back to debug signing so the
project still builds on a machine without the keystore.

## Firebase

`android/app/google-services.json` is present and registered for `com.dasun.myfinance`.
`ios/Runner/GoogleService-Info.plist` is **not** in the repository and must be downloaded
from the Firebase console before building for iOS.
