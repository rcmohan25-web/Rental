# Business rules decided with the supervisor (23 Nov 2026)

This file records the answers to the open questions in plan Section 15. Where it differs from the plan (Sections 4.3 and 4.4), **this file wins**. The API contract (`docs/api-contract.md`) turns these rules into exact fields and RPCs.

| # | Question | Decision |
| --- | --- | --- |
| 1 | Does the brief mandate a backend or architecture? Is an admin panel expected? | No backend or architecture is mandated (we keep Flutter + Supabase). An admin panel **is** needed. |
| 2 | Default commission, deposit, late fee, legal period | All are **admin-set values** in `app_settings`, not fixed in code. The deposit is a **percentage of the declared value** (`deposit_rate`) with a **fixed minimum amount** (`min_deposit_amount`) for low-value products. |
| 3 | Does the renter also pay a fee? | **No.** Sapati earns a percentage (`commission_rate`) of the rental fee. |
| 4 | Manual payment channels and account holder | **eSewa, Khalti or bank transfer.** The app shows a **static QR** for each channel. All payments go to the **Sapati company account**, also in the demo. |
| 5 | Is ID required before the first request? | **Yes, for everyone.** The user submits an ID, an admin verifies or declines it, and once verified the request moves ahead (see "ID rule"). |
| 6 | Who reviews the terms wording? | **Sapati's legal team.** |

## Team-approved initial values (24 Nov 2026)

| Setting | Value |
| --- | --- |
| `deposit_rate` | **20%** (`0.2000`) |
| `commission_rate` | **10%** (`0.1000`) |
| `late_fee_multiplier` | **1.5** (not applied until the late-return policy is approved) |

All other values (`min_deposit_amount`, `return_grace_hours`, `legal_action_period_days`, `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`) are set by an admin. The admin can change every value later; changes apply only to new requests.

## Deposit formula (replaces plan Section 4.4 deposit line)

```
deposit = max( round_half_up(declared_value x deposit_rate), min_deposit_amount )
```

Everything else in Section 4.4 is unchanged:

```
days = end - start + 1 (inclusive)         rental_fee = days x daily_price
commission = round_half_up(rental_fee x commission_rate)
renter_earning = rental_fee - commission
borrower_pays_platform = rental_fee + deposit
```

Examples with deposit_rate **20%** and an **illustrative** minimum of NPR 1,000 (the admin sets the real one):

| Declared value | 20% of value | Deposit used |
| --- | --- | --- |
| NPR 160,000 | 32,000 | **32,000** |
| NPR 2,000 | 400 | **1,000** (minimum applies) |

For a 3-day rental at daily rate NPR 3,500 (fee NPR 10,500) with declared value NPR 160,000 (20% deposit NPR 32,000), commission at 10% is NPR 1,050, the Renter earns NPR 9,450 and the Borrower pays **NPR 42,500**.

`min_deposit_amount` must not exceed `min_declared_value`, otherwise the deposit could be higher than the item's value. `admin_update_setting` rejects that.

## Settings keys (admin-set, in `app_settings`)

`commission_rate`, `deposit_rate`, **`min_deposit_amount`**, `late_fee_multiplier`, `return_grace_hours`, `legal_action_period_days`, `request_expiry_hours`, `min_declared_value`, `auto_approve_orders`.
Dart constants: `SettingKeys` in `rental_core`. The snapshot rule applies to every rate: `create_booking_request` copies `commission_rate`, `deposit_rate` and `min_deposit_amount` into the booking.

## Payments

- The Borrower scans the Sapati static QR (eSewa, Khalti or bank), pays `fee + deposit`, selects the channel, uploads the screenshot and reference. An admin verifies it (plan Section 5, step 6).
- QR images live in `apps/mobile/assets/payment_qr/` (see its README). Keep real QR images out of public repos and report screenshots.
- Every payment screen shows `HonestyTexts.manualPayment` and `HonestyTexts.paymentQrInstruction`.

## ID rule

ID must be **submitted** before a Borrower sends a first request, or a Renter publishes a listing or accepts a request (`kyc_status = none` blocks with `KYC_REQUIRED`).
An admin then **verifies or declines** the ID. A declined user sees the reason and may resubmit.
The request moves ahead to payment **only when both parties are verified**; until then the order waits in the admin ID queue and no payment instructions are shown.

## Legal wording

Terms stay marked "Prototype terms, not legal advice" until Sapati's legal team signs them off. `terms_documents.reviewed_by` and `reviewed_at` record who approved a version.

## Who changes what

| Person | Change |
| --- | --- |
| Smaran | `money.dart` and `money_cases.json`: minimum deposit rule, half-up rounding and a low-value case |
| Srijan | `app_settings` seed, `bookings.min_deposit_amount` snapshot column, SQL deposit function, validation in `admin_update_setting` |
| Mohan | Platform settings screen field "Minimum security deposit (NPR)", QR assets, honesty texts |
| Smaran + Srijan | Keep the minimum in `docs/api-contract.md` (done in v1.0) |
