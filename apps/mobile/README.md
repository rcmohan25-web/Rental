# apps/mobile (Rental, Android)

Borrower and Renter app. Package id `com.sapati.rental`, launcher label **Rental**, launch splash in brand navy.

## Run
```bash
cp ../../env/dev.example.json ../../env/dev.json   # fill in your keys
flutter run --dart-define-from-file=../../env/dev.json
```
Without the env file (or without the two keys) the app runs on the in-memory fakes, so every screen can be tried offline. In fake mode the seeded admin is admin@sapati.test / admin12345 and sign-up works in memory.

## Structure
```
lib/main.dart, app.dart          entry and MaterialApp.router (Mohan)
lib/router/mobile_router.dart    auth redirect, bottom-bar shell, each feature's routes (Mohan)
lib/config/app_env.dart          build-time config (Mohan)
lib/shared/                      image_selector (photo + compression), id_gate, main_shell (Mohan)
lib/features/<feature>/          one owner per folder, see each README
assets/payment_qr/               static eSewa, Khalti and bank QR images (see its README)
```

| Feature | Owner |
| --- | --- |
| auth, profile_kyc | Mohan |
| explore, item_details, borrower_bookings, notifications, reviews | Smaran |
| renter_listings, renter_inbox, renter_handover_return, renter_earnings | Srijan |

## Navigation
`/splash` then `/welcome`, `/login`, `/sign-up`, `/sign-up/id` for signed-out users. After sign-in the bottom bar has Explore (`/explore`), Bookings (`/bookings`), Listings (`/listings`) and Profile (`/profile`). Detail and form screens (`/item-details/:id`, `/listings/new`, `/profile/verify-id`) hide the bar.

## Shared helpers (use them, do not copy them)
- `ensureIdSubmitted(context, ref)` from `shared/id_gate.dart`: the ID gate dialog.
- `imageSelectorProvider` from `shared/image_selector.dart`: camera or gallery, compressed to about 1080 px and 300 KB, EXIF and location removed. Override it in tests.

## Android folder
Created once by `scripts/bootstrap.sh` (or `.ps1`) and committed. The main AndroidManifest declares the INTERNET permission (release builds need it). If the Android build fails with a plugin version message, raise the version in `android/settings.gradle.kts` as the message says.
