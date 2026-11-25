# apps/mobile (Rental, Android)

Borrower and Renter app. Package id `com.sapati.rental`, launcher label **Rental**, launch splash in brand navy.

## Run
```bash
cp ../../env/dev.example.json ../../env/dev.json   # fill in your keys
flutter run --dart-define-from-file=../../env/dev.json
```

## Structure
```
lib/main.dart, app.dart          entry and MaterialApp.router (Mohan)
lib/router/mobile_router.dart    aggregates each feature's routes only (Mohan)
lib/config/app_env.dart          build-time config (Mohan)
lib/skeleton/                    temporary home listing all placeholders (delete after Phase 1)
lib/features/<feature>/          one owner per folder, see each README
assets/payment_qr/               static eSewa, Khalti and bank QR images (see its README)
```

| Feature | Owner |
| --- | --- |
| auth, profile_kyc | Mohan |
| explore, item_details, borrower_bookings, notifications, reviews | Smaran |
| renter_listings, renter_inbox, renter_handover_return, renter_earnings | Srijan |

## Android folder
Created once by `scripts/bootstrap.sh` (or `.ps1`) and committed. If the Android build fails with a plugin version message, your Flutter and the Android Gradle plugin are out of step: raise the version in `android/settings.gradle.kts` as the message says.
