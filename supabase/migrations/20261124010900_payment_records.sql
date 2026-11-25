CREATE TABLE public.booking_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    submitted_by UUID NOT NULL REFERENCES public.profiles(id),
    proof_path TEXT NOT NULL UNIQUE,
    reference TEXT NOT NULL CHECK (length(btrim(reference)) > 0),
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'verified', 'rejected')),
    amount_received NUMERIC(16,2) CHECK (amount_received >= 0),
    reason TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id)
);
CREATE UNIQUE INDEX payments_one_submitted ON public.booking_payments(booking_id) WHERE status = 'submitted';
ALTER TABLE public.booking_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.booking_payments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booking_payments TO authenticated;
CREATE POLICY payments_read ON public.booking_payments FOR SELECT TO authenticated
    USING (submitted_by = auth.uid() OR public.is_admin());

CREATE FUNCTION public.submit_payment_proof(p_booking_id UUID, p_terms_accepted BOOLEAN,
    p_terms_id UUID, p_proof_path TEXT, p_reference TEXT, p_app_version TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings; v_version TEXT; v_payment UUID;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.borrower_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
    IF b.status <> 'awaiting_payment' OR b.snapshot_recorded_at IS NULL THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    PERFORM 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id) ORDER BY id FOR UPDATE;
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id IN (b.lender_id, b.borrower_id)
        AND (status <> 'active' OR kyc_status <> 'verified')) THEN RAISE EXCEPTION 'KYC_NOT_VERIFIED'; END IF;
    IF p_terms_accepted IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'TERMS_NOT_ACCEPTED'; END IF;
    IF coalesce(length(btrim(p_reference)), 0) = 0 OR coalesce(length(btrim(p_app_version)), 0) = 0
        THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    SELECT t.version INTO v_version FROM public.booking_terms bt JOIN public.terms_documents t ON t.id = bt.terms_document_id
        WHERE bt.booking_id = b.id AND bt.audience = 'borrower' AND t.id = p_terms_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'TERMS_VERSION_MISMATCH'; END IF;
    IF p_proof_path IS NULL OR split_part(p_proof_path, '/', 1) <> auth.uid()::TEXT
        OR split_part(p_proof_path, '/', 2) <> b.id::TEXT
        OR NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'payment-proof' AND name = p_proof_path)
        THEN RAISE EXCEPTION 'PROOF_MISSING'; END IF;
    INSERT INTO public.terms_acceptances(booking_id, user_id, role, terms_document_id, accepted_version, app_version)
        VALUES (b.id, auth.uid(), 'borrower', p_terms_id, v_version, p_app_version) ON CONFLICT DO NOTHING;
    INSERT INTO public.booking_payments(booking_id, submitted_by, proof_path, reference)
        VALUES (b.id, auth.uid(), p_proof_path, p_reference) RETURNING id INTO v_payment;
    UPDATE public.bookings SET status = 'payment_submitted' WHERE id = b.id;
    RETURN jsonb_build_object('id', b.id, 'status', 'payment_submitted', 'payment_id', v_payment);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_payment_proof(UUID, BOOLEAN, UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_payment_proof(UUID, BOOLEAN, UUID, TEXT, TEXT, TEXT) TO authenticated;
-- Optional idempotency argument and admin verification await the retry/code-delivery contracts.
