# Order status machine (draft from the plan, Section 5)

**Owners: Srijan (final), reviewed by all.** Every transition is an RPC that checks caller role and current status; the app never writes status directly.

| # | Transition | Who | Server checks |
| --- | --- | --- | --- |
| 1 | (new) to requested | Borrower | ID submitted, not suspended, dates free, not own item; rates and terms snapshotted |
| 2 | requested to declined / expired / cancelled | Renter, system, Borrower | Status is requested; Borrower may cancel before payment |
| 3 | requested to renter_accepted | Renter | Renter ID submitted; renter terms ticked and version matches snapshot; no date overlap |
| 4 | renter_accepted to awaiting_payment | System (both IDs verified and auto_approve_orders on) or Admin | Both IDs verified; neither user suspended |
| 5 | awaiting_payment to payment_submitted | Borrower | Borrower terms ticked; proof file and reference present |
| 6 | payment_submitted to payment_verified | Admin | Amount equals fee + deposit from snapshot (or reject with reason); 6-digit handover code generated; contact details unlock |
| 7 | payment_verified to handed_over | Renter | Handover code correct; evidence uploaded (item photos, checklist, Borrower face photo, original ID photo) |
| 8 | handed_over confirmed | Borrower | Confirms receipt and condition; disagreement flagged to admin |
| 9 | handed_over to returned | Renter | Return photos uploaded; "No issues" or damage report |
| 10 | returned to completed / disputed | Admin | Ledger entries written in the same transaction |

Overdue is a derived flag set by a scheduled job, not a status.
