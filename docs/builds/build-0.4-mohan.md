# Build 0.4, Mohan (Phase 1: identity, ID gate, admin sign-in and ID queue)

**Merge order: FIRST.** Srijan's and Smaran's Build 0.4 zips depend on files in this one.
Branch: `feature/phase1-identity`. Label the PR `phase-1`. Because it touches `packages/rental_data/lib/repositories/` the CODEOWNERS (Smaran, Srijan) must review it.

## What this build delivers
- **Data seam (Mohan's stub, Srijan replaces it):** `rental_data` interfaces `AuthRepository`, `ProfileRepository`, `KycRepository`, `AdminKycRepository`, `ImageUpload`; in-memory fakes with one shared `FakeIdentityStore` (sign-up, profile, ID submit, admin approve or reject all work offline); `RentalBackend` (the only place an app picks fake or real repositories).
- **Mobile:** splash, welcome, login, sign-up with the optional ID step ("Do it later"), profile with ID status banner, Verify identity (consent notice, misuse warning, ID photo, face photo, own-ID confirmation), bottom navigation, auth guard, `ensureIdSubmitted` ID gate and `imageSelectorProvider` for Smaran and Srijan.
- **Admin web:** sign-in page, admin role guard, sign-out, ID verification queue (approve, reject with reason).
- **Android:** INTERNET permission in the main manifest (the release APK could not reach Supabase without it).
- **Tests:** identity fakes (rental_data), auth redirect and messages, KYC banner, providers (mobile), admin guard and KYC queue (admin web).

## Not in this build (on purpose)
- Supabase implementations of these interfaces: Srijan's zip (same build, merge second).
- Payout details on the profile: Phase 3 with earnings.
- Users, orders, payments, settlement, disputes, terms manager, settings screens: Phases 2 and 3.

## Files
See `INSTALL.md` for the copy and delete lists.

## Done when (Mohan's gate)
Mobile runs on an emulator in fake mode: sign up, skip or submit the ID, see the status on Profile, sign out and in. Admin web in Chrome: sign in as admin@sapati.test, approve a pending ID. `dart format .`, `flutter analyze` and all tests pass on your machine and CI is green.
