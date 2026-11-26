# Order status machine (matches API contract v1.0, section 4)

**Owners: Srijan (final), reviewed by all.** Every transition is an RPC or a scheduled job that checks caller role and current status; the app never writes status directly.
The contract (`docs/api-contract.md`) is the source of truth. If this file and the contract differ, the contract wins.

| # | From | Trigger | To | Caller and guards |
| --- | --- | --- | --- | --- |
| 1 | new | `create_booking_request` | requested | Borrower; ID submitted; item active; dates free; rates and terms snapshotted |
| 2 | requested | `renter_decide_booking` (decline) | declined | Renter |
| 3 | requested | scheduled expiry | expired | System after `request_expiry_hours` |
| 4 | requested / renter_accepted / awaiting_payment | `cancel_booking` | cancelled | Borrower, before payment is submitted |
| 5 | requested | `renter_decide_booking` (accept) | renter_accepted | Renter ID submitted; renter terms ticked; dates free; overlapping pending requests auto-declined |
| 6 | renter_accepted | auto-approval or `admin_approve_order` (approve) | awaiting_payment | Both IDs verified; neither user suspended |
| 7 | renter_accepted | `admin_approve_order` (decline) | cancelled | Admin with reason |
| 8 | awaiting_payment | `submit_payment_proof` | payment_submitted | Borrower; borrower terms ticked; proof, reference and channel |
| 9 | payment_submitted | `admin_verify_payment` (approve) | payment_verified | Admin; amount equals fee + deposit; handover code prepared; contact details unlock |
| 10 | payment_submitted | `admin_verify_payment` (reject) | awaiting_payment | Admin with reason; Borrower may resubmit |
| 11 | payment_verified | `record_handover` | handed_over | Renter; correct unused code; evidence photos, checklist, Borrower face and ID photo |
| 12 | handed_over | `confirm_receipt` | handed_over | Borrower confirms or flags a concern |
| 13 | handed_over | `record_return` | returned | Renter; return photos; no-issues flag |
| 14 | handed_over | scheduled job | disputed | System after `end_date + return_grace_hours` with no return; sets the overdue flag |
| 15 | returned | `report_damage` | returned | Renter files an open damage report |
| 16 | returned | `admin_resolve_case` (`open_dispute`) | disputed | Admin |
| 17 | returned | `settle_booking` | completed | Admin; no open case; returned on time; two ledger entries |
| 18 | returned / disputed | `admin_resolve_case` (`no_deduction`, `deduct`, `escalate`) | completed or escalated | Admin |

Overdue is a derived flag set by a scheduled job, not a status. Escalated is a timestamp on the case, not a status.
