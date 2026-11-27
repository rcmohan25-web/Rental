-- Build 0.4 (Phase 1). api-contract v1.0 section 1 and delta 1:
--   deposit_amount = max( round_half_up(declared_value x deposit_rate), min_deposit_amount )
-- The old 5-argument calculate_money stays (minimum 0) so existing tests and callers keep working.

ALTER TABLE public.bookings
    ADD COLUMN min_deposit_amount NUMERIC(16,2) NOT NULL DEFAULT 0
    CHECK (min_deposit_amount >= 0 AND min_deposit_amount = trunc(min_deposit_amount));
-- The default 0 is truthful for every booking created before the minimum existed.

CREATE FUNCTION rental_private.calculate_money(p_days INTEGER, p_daily NUMERIC,
    p_declared NUMERIC, p_commission NUMERIC, p_deposit NUMERIC, p_min_deposit NUMERIC)
RETURNS JSONB LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE fee NUMERIC; deposit NUMERIC; commission NUMERIC;
BEGIN
    IF p_days IS NULL OR p_days <= 0 OR p_daily IS NULL OR p_declared IS NULL
        OR p_commission IS NULL OR p_deposit IS NULL OR p_min_deposit IS NULL
        OR p_daily::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_declared::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_commission::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_deposit::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_min_deposit::TEXT IN ('NaN','Infinity','-Infinity')
        OR p_daily <= 0 OR p_daily > 9999999999 OR p_daily <> trunc(p_daily)
        OR p_declared < 0 OR p_declared > 9999999999 OR p_declared <> trunc(p_declared)
        OR p_min_deposit < 0 OR p_min_deposit > 9999999999 OR p_min_deposit <> trunc(p_min_deposit)
        OR p_commission NOT BETWEEN 0 AND 1 OR p_deposit NOT BETWEEN 0 AND 1
        OR p_commission <> round(p_commission,4) OR p_deposit <> round(p_deposit,4)
        THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    fee := p_days::NUMERIC * p_daily;
    IF fee > 99999999999999 THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    deposit := greatest(round(p_declared * p_deposit, 0), p_min_deposit);
    commission := round(fee * p_commission, 0);
    RETURN jsonb_build_object('rental_fee',fee,'deposit_amount',deposit,
        'commission_amount',commission,'lender_earning',fee-commission,
        'borrower_total',fee+deposit);
END;
$$;
REVOKE ALL ON FUNCTION rental_private.calculate_money(INTEGER,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION rental_private.calculate_money(p_days INTEGER, p_daily NUMERIC,
    p_declared NUMERIC, p_commission NUMERIC, p_deposit NUMERIC)
RETURNS JSONB LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
    SELECT rental_private.calculate_money(p_days, p_daily, p_declared, p_commission, p_deposit, 0::NUMERIC);
$$;

CREATE OR REPLACE FUNCTION rental_private.valid_snapshot(b public.bookings)
RETURNS BOOLEAN LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE amounts JSONB;
BEGIN
    IF b.snapshot_recorded_at IS NULL OR NOT isfinite(b.start_date) OR NOT isfinite(b.end_date)
        OR num_nonnulls(b.agreed_daily_rate,b.declared_value_snapshot,b.rental_fee,
            b.deposit_amount,b.commission_amount,b.lender_earning) <> 6 THEN RETURN FALSE; END IF;
    amounts := rental_private.calculate_money(b.end_date-b.start_date+1,b.agreed_daily_rate,
        b.declared_value_snapshot,b.commission_rate,b.deposit_rate,b.min_deposit_amount);
    RETURN coalesce(b.rental_fee = (amounts->>'rental_fee')::NUMERIC
        AND b.deposit_amount = (amounts->>'deposit_amount')::NUMERIC
        AND b.commission_amount = (amounts->>'commission_amount')::NUMERIC
        AND b.lender_earning = (amounts->>'lender_earning')::NUMERIC, FALSE);
EXCEPTION WHEN SQLSTATE 'P0001' OR numeric_value_out_of_range OR datetime_field_overflow THEN
    RETURN FALSE;
END;
$$;

-- The minimum is part of the immutable snapshot.
CREATE OR REPLACE FUNCTION public.guard_booking_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF OLD.snapshot_recorded_at IS NOT NULL AND
        ROW(NEW.item_id, NEW.lender_id, NEW.borrower_id, NEW.start_date, NEW.end_date,
            NEW.agreed_daily_rate, NEW.declared_value_snapshot, NEW.rental_fee,
            NEW.deposit_amount, NEW.commission_rate, NEW.deposit_rate, NEW.min_deposit_amount,
            NEW.commission_amount, NEW.lender_earning, NEW.snapshot_recorded_at, NEW.terms_version_ids)
        IS DISTINCT FROM
        ROW(OLD.item_id, OLD.lender_id, OLD.borrower_id, OLD.start_date, OLD.end_date,
            OLD.agreed_daily_rate, OLD.declared_value_snapshot, OLD.rental_fee,
            OLD.deposit_amount, OLD.commission_rate, OLD.deposit_rate, OLD.min_deposit_amount,
            OLD.commission_amount, OLD.lender_earning, OLD.snapshot_recorded_at, OLD.terms_version_ids)
        THEN RAISE EXCEPTION 'SNAPSHOT_IMMUTABLE'; END IF;
    RETURN NEW;
END;
$$;

-- create_booking_request: same as migration 20261124011600 plus min_deposit_amount.
-- A missing or invalid min_deposit_amount fails closed with SETTING_UNAVAILABLE.
CREATE OR REPLACE FUNCTION public.create_booking_request(p_item_id UUID,p_start_date DATE,p_end_date DATE)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE i public.items; b public.bookings; v_rates JSONB; v_money JSONB; v_terms UUID[];
    v_expiry NUMERIC; v_min NUMERIC; v_mindep NUMERIC;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    IF NOT public.can_rent() THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
    IF p_start_date IS NULL OR p_end_date IS NULL OR NOT isfinite(p_start_date) OR NOT isfinite(p_end_date)
        OR p_end_date<p_start_date OR p_start_date<(NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE
        THEN RAISE EXCEPTION 'INVALID_DATES'; END IF;
    SELECT * INTO i FROM public.items WHERE id=p_item_id FOR UPDATE;
    IF NOT FOUND OR i.status<>'active' OR i.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'ITEM_UNAVAILABLE'; END IF;
    IF i.lender_id=auth.uid() THEN RAISE EXCEPTION 'OWN_ITEM'; END IF;
    PERFORM 1 FROM public.profiles WHERE id IN (i.lender_id,auth.uid()) ORDER BY id FOR UPDATE;
    IF EXISTS(SELECT 1 FROM public.profiles WHERE id IN(i.lender_id,auth.uid())
        AND (status<>'active' OR kyc_status NOT IN('pending','verified'))) THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
    IF EXISTS(SELECT 1 FROM public.bookings WHERE item_id=i.id AND status IN
        ('renter_accepted','awaiting_payment','payment_submitted','payment_verified','handed_over','returned','disputed')
        AND daterange(start_date,end_date,'[]') && daterange(p_start_date,p_end_date,'[]')) THEN RAISE EXCEPTION 'DATES_TAKEN'; END IF;
    IF EXISTS(SELECT 1 FROM public.bookings WHERE item_id=i.id AND borrower_id=auth.uid()
        AND status='requested' AND (expires_at IS NULL OR expires_at>NOW())
        AND start_date=p_start_date AND end_date=p_end_date) THEN RAISE EXCEPTION 'DUPLICATE_REQUEST'; END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(624001);
    PERFORM pg_catalog.pg_advisory_xact_lock(624002);
    SELECT jsonb_object_agg(key,value) INTO v_rates FROM public.app_settings;
    IF coalesce(jsonb_typeof(v_rates->'commission_rate'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'deposit_rate'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'min_deposit_amount'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'request_expiry_hours'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'min_declared_value'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'auto_approve_orders'),'null')<>'boolean'
        THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
    v_expiry := (v_rates->>'request_expiry_hours')::NUMERIC;
    v_min := (v_rates->>'min_declared_value')::NUMERIC;
    v_mindep := (v_rates->>'min_deposit_amount')::NUMERIC;
    IF v_expiry<=0 OR v_min<0 OR v_min<>trunc(v_min)
        OR v_mindep<0 OR v_mindep<>trunc(v_mindep) OR v_mindep>v_min THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
    IF i.declared_value IS NULL OR i.declared_value<v_min THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    v_money := rental_private.calculate_money(p_end_date-p_start_date+1,i.daily_rate,i.declared_value,
        (v_rates->>'commission_rate')::NUMERIC,(v_rates->>'deposit_rate')::NUMERIC,v_mindep);
    SELECT array_agg(id ORDER BY audience) INTO v_terms FROM public.terms_documents
        WHERE is_active AND status='published' AND published_at IS NOT NULL AND audience IN('general','borrower','renter');
    IF coalesce(cardinality(v_terms),0)<>3 THEN RAISE EXCEPTION 'TERMS_UNAVAILABLE'; END IF;
    INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,
        min_deposit_amount,agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,
        lender_earning,snapshot_recorded_at,terms_version_ids,expires_at)
    VALUES(i.id,i.lender_id,auth.uid(),p_start_date,p_end_date,(v_rates->>'commission_rate')::NUMERIC,
        (v_rates->>'deposit_rate')::NUMERIC,v_mindep,i.daily_rate,i.declared_value,(v_money->>'rental_fee')::NUMERIC,
        (v_money->>'deposit_amount')::NUMERIC,(v_money->>'commission_amount')::NUMERIC,
        (v_money->>'lender_earning')::NUMERIC,NOW(),v_terms,NOW()+v_expiry*INTERVAL '1 hour') RETURNING * INTO b;
    INSERT INTO public.booking_terms(booking_id,audience,terms_document_id)
        SELECT b.id,audience,id FROM public.terms_documents WHERE id=ANY(v_terms);
    PERFORM rental_private.require_booking_integrity(b.id);
    RETURN to_jsonb(b);
END;
$$;
REVOKE ALL ON FUNCTION public.create_booking_request(UUID,DATE,DATE) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_booking_request(UUID,DATE,DATE) TO authenticated;
