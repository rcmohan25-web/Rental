# Business rules decided with the supervisor (23 Nov 2026)

This file records the answers to the open questions in plan Section 15. Where it differs from the plan (Sections 4.3 and 4.4), **this file wins**.

| # | Question | Decision |
| --- | --- | --- |
| 1 | Does the brief mandate a backend or architecture? Is an admin panel expected? | No backend or architecture is mandated (we keep Flutter + Supabase). An admin panel **is** needed. |
| 2 | Default commission, deposit, late fee, legal period | All are **admin-set values** in `app_settings`, not fixed in code. The deposit is a **percentage of the declared value** (`deposit_rate`) with a **fixed minimum amount** (`min_deposit_amount`) for low-value products. |
| 3 | Does the renter also pay a fee? | **No.** Sapati earns a percentage (`commission_rate`) of the rental fee. |
| 4 | Manual payment channels and account holder | **eSewa, Khalti or bank transfer.** The app shows a **static QR** for each channel. All payments go to the **Sapati company account**, also in the demo. |
| 5 | Is ID required before the first request? | **Yes, for everyone** (the plan's ID gate). |
| 6 | Who reviews the terms wording? | **Sapati's legal team.** |

## Deposit formula (replaces plan Section 4.4 deposit line)

```
deposit = max( round(declared_value x deposit_rate), min_deposit_amount )
```

Everything else in Section 4.4 is unchanged:

```
days = end - start + 1 (inclusive)         rental_fee = days x daily_price
commission = rental_fee x commission_rate   renter_earning = rental_fee - commission
borrower_pays_platform = rental_fee + deposit
```

Examples with deposit_rate 25% and an **illustrative** minimum of NPR 1,000 (the admin sets the real one):

| Declared value | 25% of value | Deposit used |
| --- | --- | --- |
| NPR 160,000 | 40,000 | **40,000** |
| NPR 2,000 | 500 | **1,000** (minimum applies) |

Open point for Smaran and Srijan: `min_deposit_amount` should not exceed `min_declared_value`, otherwise the deposit could be higher than the item's value. Suggest `admin_update_setting` rejects that.

## Settings keys (admin-set, in `app_settings`)

`commission_rate`, `deposit_rate`, **`min_deposit_amount` (new)**, `late_fee_multiplier`, `return_grace_hours`, `legal_action_period_days`, `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`.
Dart constants: `SettingKeys` in `rental_core`. The snapshot rule applies to every rate: `create_booking_request` copies `commission_rate`, `deposit_rate` and `min_deposit_amount` into the booking.

## Payments

- The Borrower scans the Sapati static QR (eSewa, Khalti or bank), pays `fee + deposit`, uploads the screenshot and reference. An admin verifies it (plan Section 5, step 6).
- QR images live in `apps/mobile/assets/payment_qr/` (see its README). Keep real QR images out of public repos and report screenshots.
- Every payment screen shows `HonestyTexts.manualPayment` and `HonestyTexts.paymentQrInstruction`.

## ID rule

ID must be **submitted** before a Borrower sends a first request or a Renter publishes a listing or accepts a request. Payment instructions are released only when **both** parties are **verified** by an admin (plan Section 4.1). Please confirm with the supervisor that "submitted" (pending) is enough to send the request; if "verified" is required first, only the gate check changes.

## Legal wording

Terms stay marked "Prototype terms, not legal advice" until Sapati's legal team signs them off. Suggested (backend-request): `terms_documents.reviewed_by` and `reviewed_at`, so the admin Terms manager can show who approved a version.

## Who changes what

| Person | Change |
| --- | --- |
| Smaran | `money.dart` and `money_cases.json`: minimum deposit rule and a low-value case |
| Srijan | `app_settings` seed, `bookings.min_deposit_amount` snapshot column, SQL deposit function, validation in `admin_update_setting` |
| Mohan | Platform settings screen field "Minimum security deposit (NPR)", QR assets, honesty texts (done in Build 0.2) |
| Smaran + Srijan | Mention the minimum in `docs/api-contract.md` before it is frozen |
