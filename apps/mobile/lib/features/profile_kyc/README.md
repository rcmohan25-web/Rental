# profile_kyc

**Owner: Mohan**

Profile edit, ID upload with consent notice, verification status banner, ID gate.

Layout
- `routes.dart`: `/profile` (Profile tab) and `/profile/verify-id`.
- `application/profile_providers.dart`: `profileRepositoryProvider`, `kycRepositoryProvider`, `myProfileProvider`, `myKycStatusProvider`.
- `presentation/profile_kyc_screen.dart`: edit name, phone, area; ID status; sign out.
- `presentation/verify_id_screen.dart`: the ID form or the current status.
- `presentation/widgets/id_upload_form.dart`: ID photo, face photo, consent notice, misuse warning, own-ID confirmation, submit. Also used by the sign-up ID step.
- `presentation/widgets/kyc_status_banner.dart`: none, pending, verified, rejected (with reason).

The ID gate for other features lives in `apps/mobile/lib/shared/id_gate.dart`:
`if (!await ensureIdSubmitted(context, ref)) return;` before sending a request, publishing a listing or accepting a request.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
