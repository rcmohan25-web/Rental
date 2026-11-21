# API contract

**Owners: Smaran + Srijan. Frozen after Phase 0** (changes need a PR approved by all three).

Fill in, per RPC: name, params, result, errors, who may call it, status transition.
RPC names from the plan: `create_booking_request`, `renter_decide_booking` (terms_accepted flag), `admin_approve_order`,
`submit_payment_proof` (terms_accepted flag), `admin_verify_payment`, `record_handover`, `confirm_receipt`, `record_return`,
`report_damage`, `admin_resolve_case`, `settle_booking`, `admin_review_kyc`, `admin_update_setting`, `admin_publish_terms`,
`admin_set_user_status`, `request_account_deletion`.

Entities to define first: Booking, Item, Profile, Ledger, Terms.

Naming: in code and database use `lender_id` (the Renter) and `borrower_id`; the UI shows "Renter" and "Borrower".
