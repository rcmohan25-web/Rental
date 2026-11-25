CREATE FUNCTION rental_private.require_booking_integrity(p_booking_id UUID, p_acceptance TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings;
BEGIN
    SELECT * INTO b FROM public.bookings WHERE id=p_booking_id;
    IF NOT FOUND OR NOT rental_private.valid_snapshot(b) THEN RAISE EXCEPTION 'INVALID_SNAPSHOT'; END IF;
    IF cardinality(b.terms_version_ids) <> 3 OR
        (SELECT count(*) FROM public.booking_terms bt JOIN public.terms_documents t ON t.id=bt.terms_document_id
         WHERE bt.booking_id=b.id AND t.audience=bt.audience AND t.status IN ('published','archived')
           AND t.published_at IS NOT NULL AND t.id=ANY(b.terms_version_ids)) <> 3 THEN
        RAISE EXCEPTION 'TERMS_SNAPSHOT_INCOMPLETE';
    END IF;
    IF p_acceptance IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.terms_acceptances a JOIN public.booking_terms bt
          ON bt.booking_id=a.booking_id AND bt.audience=a.role AND bt.terms_document_id=a.terms_document_id
        JOIN public.terms_documents t ON t.id=a.terms_document_id
        WHERE a.booking_id=b.id AND a.role=p_acceptance AND a.accepted_version=t.version
          AND a.user_id=CASE p_acceptance WHEN 'renter' THEN b.lender_id WHEN 'borrower' THEN b.borrower_id END
          AND length(btrim(a.app_version))>0) THEN RAISE EXCEPTION 'TERMS_NOT_ACCEPTED'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION rental_private.require_booking_integrity(UUID,TEXT) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION rental_private.check_new_booking_terms()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NEW.snapshot_recorded_at IS NOT NULL THEN
        PERFORM rental_private.require_booking_integrity(NEW.id);
    END IF;
    RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER booking_complete_terms AFTER INSERT ON public.bookings
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION rental_private.check_new_booking_terms();

-- Include legacy titles in allocation without editing or reclassifying history.
CREATE OR REPLACE FUNCTION public.admin_publish_terms(p_audience TEXT,p_body TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id UUID; v_version TEXT; v_old UUID;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_audience IS NULL OR p_audience NOT IN ('general','borrower','renter')
        OR coalesce(length(btrim(p_body)),0)=0 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(624002);
    SELECT (coalesce(max(version::NUMERIC),0)+1)::TEXT INTO v_version FROM public.terms_documents
        WHERE (audience=p_audience OR title=p_audience || ' terms') AND version ~ '^[0-9]+$';
    SELECT id INTO v_old FROM public.terms_documents WHERE audience=p_audience AND is_active FOR UPDATE;
    UPDATE public.terms_documents SET is_active=FALSE,status='archived',archived_at=NOW() WHERE id=v_old;
    INSERT INTO public.terms_documents(title,version,content,status,audience,is_active,published_at)
        VALUES(p_audience || ' terms',v_version,p_body,'published',p_audience,TRUE,NOW()) RETURNING id INTO v_id;
    INSERT INTO public.audit_log(actor_id,action,target_id,before_value,after_value)
        VALUES(auth.uid(),'publish_terms',p_audience,jsonb_build_object('id',v_old),jsonb_build_object('id',v_id));
    RETURN jsonb_build_object('id',v_id,'version',v_version,'audience',p_audience);
END;
$$;

-- No retry-key contract is invented. Identical live requests are rejected under
-- the item lock. Missing expiry/minimum/auto-approval configuration fails closed.
CREATE FUNCTION public.create_booking_request(p_item_id UUID,p_start_date DATE,p_end_date DATE)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE i public.items; b public.bookings; v_rates JSONB; v_money JSONB; v_terms UUID[];
    v_expiry NUMERIC; v_min NUMERIC;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    IF NOT public.can_rent() THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
    IF p_start_date IS NULL OR p_end_date IS NULL OR NOT isfinite(p_start_date) OR NOT isfinite(p_end_date)
        OR p_end_date<p_start_date OR p_start_date<(NOW() AT TIME ZONE 'Asia/Kathmandu')::DATE
        THEN RAISE EXCEPTION 'INVALID_DATES'; END IF;
    SELECT * INTO i FROM public.items WHERE id=p_item_id FOR UPDATE;
    IF NOT FOUND OR i.status<>'active' THEN RAISE EXCEPTION 'ITEM_UNAVAILABLE'; END IF;
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
    -- Same lock order as setting/publication writers: one consistent configuration snapshot.
    PERFORM pg_catalog.pg_advisory_xact_lock(624001);
    PERFORM pg_catalog.pg_advisory_xact_lock(624002);
    SELECT jsonb_object_agg(key,value) INTO v_rates FROM public.app_settings;
    IF coalesce(jsonb_typeof(v_rates->'commission_rate'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'deposit_rate'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'request_expiry_hours'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'min_declared_value'),'null')<>'number'
        OR coalesce(jsonb_typeof(v_rates->'auto_approve_orders'),'null')<>'boolean'
        THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
    v_expiry := (v_rates->>'request_expiry_hours')::NUMERIC;
    v_min := (v_rates->>'min_declared_value')::NUMERIC;
    IF v_expiry<=0 OR v_min<0 OR v_min<>trunc(v_min) THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
    IF i.declared_value IS NULL OR i.declared_value<v_min THEN RAISE EXCEPTION 'INVALID_MONEY'; END IF;
    v_money := rental_private.calculate_money(p_end_date-p_start_date+1,i.daily_rate,i.declared_value,
        (v_rates->>'commission_rate')::NUMERIC,(v_rates->>'deposit_rate')::NUMERIC);
    SELECT array_agg(id ORDER BY audience) INTO v_terms FROM public.terms_documents
        WHERE is_active AND status='published' AND published_at IS NOT NULL AND audience IN('general','borrower','renter');
    IF coalesce(cardinality(v_terms),0)<>3 THEN RAISE EXCEPTION 'TERMS_UNAVAILABLE'; END IF;
    INSERT INTO public.bookings(item_id,lender_id,borrower_id,start_date,end_date,commission_rate,deposit_rate,
        agreed_daily_rate,declared_value_snapshot,rental_fee,deposit_amount,commission_amount,lender_earning,
        snapshot_recorded_at,terms_version_ids,expires_at)
    VALUES(i.id,i.lender_id,auth.uid(),p_start_date,p_end_date,(v_rates->>'commission_rate')::NUMERIC,
        (v_rates->>'deposit_rate')::NUMERIC,i.daily_rate,i.declared_value,(v_money->>'rental_fee')::NUMERIC,
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
