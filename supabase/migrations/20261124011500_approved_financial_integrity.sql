-- Approved 24 November: fractional SQL rates; Dart uses bps (x100 for multiplier).
-- Preserve any existing administrator configuration; never rewrite old snapshots.
INSERT INTO public.app_settings(key, value) VALUES
    ('commission_rate', '0.1000'), ('deposit_rate', '0.2000'), ('late_fee_multiplier', '1.5')
ON CONFLICT (key) DO NOTHING;

-- A schema-local REVOKE cannot remove PostgreSQL's global PUBLIC EXECUTE default.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_updated_at(), public.validate_setting(),
    public.guard_booking_snapshot(), public.guard_terms_document(), public.validate_booking_terms(),
    public.validate_acceptance(), public.validate_listing(), public.notify_booking_status()
FROM PUBLIC, anon, authenticated;

CREATE FUNCTION rental_private.calculate_money(p_days INTEGER, p_daily NUMERIC,
    p_declared NUMERIC, p_commission NUMERIC, p_deposit NUMERIC)
RETURNS JSONB LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE fee NUMERIC; deposit NUMERIC; commission NUMERIC;
BEGIN
    IF p_days IS NULL OR p_days <= 0 OR p_daily IS NULL OR p_declared IS NULL
        OR p_commission IS NULL OR p_deposit IS NULL
        OR p_daily::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_declared::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_commission::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_deposit::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_daily <= 0 OR p_daily > 9999999999 OR p_daily <> trunc(p_daily)
        OR p_declared < 0 OR p_declared > 9999999999 OR p_declared <> trunc(p_declared)
        OR p_commission NOT BETWEEN 0 AND 1 OR p_deposit NOT BETWEEN 0 AND 1
        OR p_commission <> round(p_commission,4) OR p_deposit <> round(p_deposit,4)
        THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    fee := p_days::NUMERIC * p_daily;
    IF fee > 99999999999999 THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    -- NUMERIC round is half away from zero: half-up for our nonnegative amounts.
    deposit := round(p_declared * p_deposit, 0);
    commission := round(fee * p_commission, 0);
    RETURN jsonb_build_object('rental_fee',fee,'deposit_amount',deposit,
        'commission_amount',commission,'lender_earning',fee-commission,
        'borrower_total',fee+deposit);
END;
$$;
REVOKE ALL ON FUNCTION rental_private.calculate_money(INTEGER,NUMERIC,NUMERIC,NUMERIC,NUMERIC)
FROM PUBLIC, anon, authenticated;

CREATE FUNCTION rental_private.valid_snapshot(b public.bookings)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE amounts JSONB;
BEGIN
    IF b.snapshot_recorded_at IS NULL OR NOT isfinite(b.start_date) OR NOT isfinite(b.end_date)
        OR num_nonnulls(b.agreed_daily_rate,b.declared_value_snapshot,b.rental_fee,
            b.deposit_amount,b.commission_amount,b.lender_earning) <> 6 THEN RETURN FALSE; END IF;
    amounts := rental_private.calculate_money(b.end_date-b.start_date+1,b.agreed_daily_rate,
        b.declared_value_snapshot,b.commission_rate,b.deposit_rate);
    RETURN coalesce(b.rental_fee = (amounts->>'rental_fee')::NUMERIC
        AND b.deposit_amount = (amounts->>'deposit_amount')::NUMERIC
        AND b.commission_amount = (amounts->>'commission_amount')::NUMERIC
        AND b.lender_earning = (amounts->>'lender_earning')::NUMERIC, FALSE);
EXCEPTION WHEN SQLSTATE 'P0001' OR numeric_value_out_of_range OR datetime_field_overflow THEN
    RETURN FALSE;
END;
$$;
REVOKE ALL ON FUNCTION rental_private.valid_snapshot(public.bookings) FROM PUBLIC, anon, authenticated;
-- NOT VALID deliberately preserves legacy data without certifying it. New writes
-- are checked; invalid historical rows need explicit reconciliation, not backfill.
ALTER TABLE public.bookings ADD CONSTRAINT booking_financial_integrity
    CHECK (snapshot_recorded_at IS NULL OR rental_private.valid_snapshot(bookings)) NOT VALID;
ALTER TABLE public.ledger_entries ADD CONSTRAINT ledger_whole_finite_amount
    CHECK (amount::TEXT NOT IN ('NaN','Infinity','-Infinity') AND amount = trunc(amount)) NOT VALID;

CREATE FUNCTION rental_private.prevent_snapshot_backfill()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF OLD.snapshot_recorded_at IS NULL AND NEW.snapshot_recorded_at IS NOT NULL THEN
        RAISE EXCEPTION 'LEGACY_RECONCILIATION_REQUIRED';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER booking_no_silent_backfill BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION rental_private.prevent_snapshot_backfill();
