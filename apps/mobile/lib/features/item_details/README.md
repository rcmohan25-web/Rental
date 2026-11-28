# item_details

**Owner: Smaran**

Photo carousel, condition, daily price, deposit shown separately, date picker with blocked dates, cost breakdown.

Layout
- `routes.dart`: `/item-details` and `/item-details/:id`.
- `application/`: `itemDetailsProvider` (item, blocked dates, settings loaded together, never throws), friendly booking errors, idempotency key.
- `presentation/`: the screen, `CostBreakdownCard`, `PhotoCarousel`.

Money: every number comes from `Money` in `rental_core` (deposit = max(deposit rate x declared value, `min_deposit_amount`)). Nothing is calculated in a widget.
ID gate: "Send rental request" calls `ensureIdSubmitted` (`shared/id_gate.dart`) first.
Live backend: while bookings are still a fake (until Phase 2) `bookingRequestsEnabledProvider` is false and the screen shows a notice instead of the send button.

Rules: use repository interfaces from `rental_data` (fakes first), no direct Supabase calls from screens,
handle loading, empty and error states, edit only this folder (open an issue for anything else).
