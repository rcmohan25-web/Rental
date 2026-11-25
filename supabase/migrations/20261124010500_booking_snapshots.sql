-- Legacy bookings remain explicitly unsnapshotted; never infer their historical prices.
ALTER TABLE public.bookings
    ADD COLUMN rental_days INTEGER GENERATED ALWAYS AS (end_date - start_date + 1) STORED,
    ADD COLUMN agreed_daily_rate NUMERIC(12,2),
    ADD COLUMN declared_value_snapshot NUMERIC(12,2),
    ADD COLUMN rental_fee NUMERIC(16,2),
    ADD COLUMN deposit_amount NUMERIC(16,2),
    ADD COLUMN commission_amount NUMERIC(16,2),
    ADD COLUMN lender_earning NUMERIC(16,2),
    ADD COLUMN snapshot_recorded_at TIMESTAMPTZ,
    ADD COLUMN expires_at TIMESTAMPTZ,
    ADD COLUMN receipt_confirmed_at TIMESTAMPTZ,
    ADD COLUMN returned_at TIMESTAMPTZ,
    ADD COLUMN decline_reason TEXT,
    ADD COLUMN is_overdue BOOLEAN NOT NULL DEFAULT FALSE,
    ADD CONSTRAINT booking_snapshot_complete CHECK (
        num_nonnulls(agreed_daily_rate, declared_value_snapshot, rental_fee,
            deposit_amount, commission_amount, lender_earning, snapshot_recorded_at) IN (0, 7)),
    ADD CONSTRAINT booking_snapshot_values CHECK (snapshot_recorded_at IS NULL OR (
        agreed_daily_rate > 0 AND declared_value_snapshot >= 0
        AND rental_fee = rental_days * agreed_daily_rate
        AND deposit_amount >= 0 AND deposit_amount = trunc(deposit_amount)
        AND commission_amount BETWEEN 0 AND rental_fee
        AND lender_earning = rental_fee - commission_amount));
ALTER TABLE public.bookings ALTER COLUMN commission_rate DROP DEFAULT;
ALTER TABLE public.bookings ALTER COLUMN deposit_rate DROP DEFAULT;

CREATE FUNCTION public.guard_booking_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF OLD.snapshot_recorded_at IS NOT NULL AND
        ROW(NEW.item_id, NEW.lender_id, NEW.borrower_id, NEW.start_date, NEW.end_date,
            NEW.agreed_daily_rate, NEW.declared_value_snapshot, NEW.rental_fee,
            NEW.deposit_amount, NEW.commission_rate, NEW.deposit_rate,
            NEW.commission_amount, NEW.lender_earning, NEW.snapshot_recorded_at, NEW.terms_version_ids)
        IS DISTINCT FROM
        ROW(OLD.item_id, OLD.lender_id, OLD.borrower_id, OLD.start_date, OLD.end_date,
            OLD.agreed_daily_rate, OLD.declared_value_snapshot, OLD.rental_fee,
            OLD.deposit_amount, OLD.commission_rate, OLD.deposit_rate,
            OLD.commission_amount, OLD.lender_earning, OLD.snapshot_recorded_at, OLD.terms_version_ids)
        THEN RAISE EXCEPTION 'SNAPSHOT_IMMUTABLE'; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER bookings_guard_snapshot BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.guard_booking_snapshot();
-- Creation RPC and exact commission/deposit tie-breaking remain blocked on agreement.
