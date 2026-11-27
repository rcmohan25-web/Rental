# Proposal: API contract v1.1 (Build 0.4 additions)

Open a PR labelled `contract-change` that edits `docs/api-contract.md` as below. It needs all three approvals (Mohan, Smaran, Srijan). All changes are **additive**, so the version is v1.1.

## Edits

1. Section 5.2 (supplemental RPCs): add

   | RPC | Caller | Arguments | Returns | Status |
   | --- | --- | --- | --- | --- |
   | `delete_item` | Item owner | `p_item_id uuid` | `{id, deleted: true}`. Errors: `ACCOUNT_RESTRICTED`, `NOT_ALLOWED`, `ACTIVE_BOOKINGS_EXIST`. Soft delete; pending requests are declined with reason `item_deleted`. | IMPLEMENTED |

2. Section 5.2: mark `get_public_settings` as IMPLEMENTED.
3. Section 5.3 (direct reads): add `public_items` (view) for anonymous and signed-in reads of public cards, with `lender_first_name`; say that Explore and Item details read it instead of `items`. Add: "Clients no longer have DELETE on `items`; use `delete_item`."
4. Section 2.1 and 2.2: `items.deleted_at` IMPLEMENTED; `bookings.min_deposit_amount` IMPLEMENTED (not null, default 0 for rows created before the minimum existed).
5. Section 3.1: `min_deposit_amount` accepted by `admin_update_setting`; also rejected when above `min_declared_value`, and `min_declared_value` is rejected when below `min_deposit_amount`. `create_booking_request` fails with `SETTING_UNAVAILABLE` when it is unset (dev seed sets 1000, illustrative).
6. Section 11 (error codes): add the client-side auth codes `INVALID_CREDENTIALS`, `EMAIL_TAKEN`, `WEAK_PASSWORD`, `EMAIL_NOT_CONFIRMED`, `NETWORK`, `IMAGE_TOO_LARGE`, `UPLOAD_FAILED`, `UNKNOWN`. They come from the Auth and Storage services or the client, not from RPCs.
7. Section 12: items 1 (minimum deposit: whitelist, calculator, snapshot, cross-check) and 11 (`items.deleted_at` only) move to done; item 8 loses `get_public_settings`.
8. Change log row: `v1.1 | 2026-11-27 | Phase 1 additions: delete_item, public_items, get_public_settings, min_deposit_amount, auth client codes | pending approvals`.

## Not part of this proposal
Model changes (settings and booking `minDepositAmount`) are in Smaran's PR, labelled `contract-change` too, because `packages/rental_data/lib/models` is frozen.
