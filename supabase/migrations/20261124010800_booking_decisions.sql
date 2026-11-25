CREATE FUNCTION public.renter_decide_booking(p_booking_id UUID, p_accept BOOLEAN,
    p_terms_accepted BOOLEAN, p_terms_id UUID DEFAULT NULL, p_reason TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings; v_version TEXT; v_auto BOOLEAN;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.lender_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
    IF b.status <> 'requested' OR (b.expires_at IS NOT NULL AND b.expires_at <= NOW()) THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF p_accept IS NULL THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    IF NOT p_accept THEN
        UPDATE public.bookings SET status = 'declined', decline_reason = p_reason WHERE id = b.id;
    ELSE
        IF NOT public.can_rent() THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
        IF b.snapshot_recorded_at IS NULL THEN RAISE EXCEPTION 'SNAPSHOT_REQUIRED'; END IF;
        IF p_terms_accepted IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'TERMS_NOT_ACCEPTED'; END IF;
        IF coalesce(length(btrim(p_app_version)), 0) = 0 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        SELECT t.version INTO v_version FROM public.booking_terms bt JOIN public.terms_documents t ON t.id = bt.terms_document_id
            WHERE bt.booking_id = b.id AND bt.audience = 'renter' AND t.id = p_terms_id;
        IF NOT FOUND THEN RAISE EXCEPTION 'TERMS_VERSION_MISMATCH'; END IF;
        PERFORM 1 FROM public.items WHERE id = b.item_id AND status = 'active' FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'ITEM_UNAVAILABLE'; END IF;
        PERFORM 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id) ORDER BY id FOR UPDATE;
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id) AND status <> 'active')
            THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
        SELECT (value #>> '{}')::BOOLEAN INTO v_auto FROM public.app_settings
            WHERE key = 'auto_approve_orders' AND jsonb_typeof(value) = 'boolean';
        IF v_auto IS NULL THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
        INSERT INTO public.terms_acceptances(booking_id, user_id, role, terms_document_id, accepted_version, app_version)
            VALUES (b.id, auth.uid(), 'renter', p_terms_id, v_version, p_app_version);
        UPDATE public.bookings SET status = CASE WHEN v_auto AND NOT EXISTS (
            SELECT 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id) AND kyc_status <> 'verified')
            THEN 'awaiting_payment' ELSE 'renter_accepted' END WHERE id = b.id;
    END IF;
    RETURN (SELECT jsonb_build_object('id', id, 'status', status) FROM public.bookings WHERE id = b.id);
EXCEPTION WHEN exclusion_violation THEN RAISE EXCEPTION 'DATES_TAKEN';
END;
$$;
CREATE FUNCTION public.admin_approve_order(p_booking_id UUID, p_approve BOOLEAN, p_reason TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_approve IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'ORDER_REJECTION_NOT_APPROVED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.status <> 'renter_accepted' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    PERFORM 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id) ORDER BY id FOR UPDATE;
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id)
        AND (status <> 'active' OR kyc_status <> 'verified')) THEN RAISE EXCEPTION 'KYC_NOT_VERIFIED'; END IF;
    UPDATE public.bookings SET status = 'awaiting_payment' WHERE id = b.id;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'approve_order', b.id::TEXT, to_jsonb(b.status), to_jsonb('awaiting_payment'::TEXT));
    RETURN jsonb_build_object('id', b.id, 'status', 'awaiting_payment');
END;
$$;
REVOKE ALL ON FUNCTION public.renter_decide_booking(UUID, BOOLEAN, BOOLEAN, UUID, TEXT, TEXT),
    public.admin_approve_order(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renter_decide_booking(UUID, BOOLEAN, BOOLEAN, UUID, TEXT, TEXT),
    public.admin_approve_order(UUID, BOOLEAN, TEXT) TO authenticated;
