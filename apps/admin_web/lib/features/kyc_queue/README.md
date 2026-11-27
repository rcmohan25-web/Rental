# kyc_queue

**Owner: Mohan**

Review ID and face photos via short-lived signed URLs, approve or reject with a reason.

Layout
- `routes.dart`: exposes `kycQueueRoutes` (`/kyc`).
- `application/kyc_queue_providers.dart`: `pendingKycProvider` (invalidate to reload and get fresh signed URLs).
- `presentation/kyc_queue_screen.dart`: one card per pending ID: name, submit time, ID photo, face photo (tap to enlarge), "Mark as checked" and "Reject" (reason required).

"Verified" means checked by an admin. No automatic face matching.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
