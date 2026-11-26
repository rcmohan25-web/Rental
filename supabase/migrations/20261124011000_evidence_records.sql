CREATE TABLE public.handover_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    stage TEXT NOT NULL CHECK (stage IN ('pickup', 'return')),
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    item_photo_paths TEXT[] NOT NULL CHECK (cardinality(item_photo_paths) > 0),
    checklist JSONB,
    borrower_face_path TEXT,
    borrower_id_photo_path TEXT,
    no_issues BOOLEAN,
    note TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (booking_id, stage),
    CHECK (stage <> 'pickup' OR (checklist IS NOT NULL AND jsonb_typeof(checklist) = 'object'
        AND borrower_face_path IS NOT NULL AND borrower_id_photo_path IS NOT NULL))
);
CREATE TABLE public.damage_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    reported_by UUID NOT NULL REFERENCES public.profiles(id),
    description TEXT NOT NULL CHECK (length(btrim(description)) > 0),
    photo_paths TEXT[] NOT NULL CHECK (cardinality(photo_paths) > 0),
    claimed_amount NUMERIC(16,2) NOT NULL CHECK (claimed_amount >= 0),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'escalated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX damage_one_open ON public.damage_reports(booking_id) WHERE status IN ('open', 'escalated');
CREATE TABLE public.receipt_confirmations (
    booking_id UUID PRIMARY KEY REFERENCES public.bookings(id),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    condition_ok BOOLEAN NOT NULL,
    note TEXT,
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (condition_ok OR (note IS NOT NULL AND length(btrim(note)) > 0))
);
ALTER TABLE public.receipt_confirmations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.receipt_confirmations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.receipt_confirmations TO authenticated;
CREATE POLICY receipt_read ON public.receipt_confirmations FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));
ALTER TABLE public.handover_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.damage_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.handover_records, public.damage_reports FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.handover_records, public.damage_reports TO authenticated;
CREATE POLICY handover_admin_read ON public.handover_records FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY damage_admin_read ON public.damage_reports FOR SELECT TO authenticated USING (public.is_admin());

-- Internal helper only. Paths remain under the uploader folder as required by the plan.
CREATE FUNCTION public.check_evidence_paths(p_booking_id UUID, p_paths TEXT[])
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_path TEXT;
BEGIN
    IF p_paths IS NULL OR cardinality(p_paths) = 0 THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
    FOREACH v_path IN ARRAY p_paths LOOP
        IF v_path IS NULL OR split_part(v_path, '/', 1) <> auth.uid()::TEXT
            OR split_part(v_path, '/', 2) <> p_booking_id::TEXT
            OR NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'handover' AND name = v_path)
            THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
    END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.check_evidence_paths(UUID, TEXT[]) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.record_return(p_booking_id UUID, p_return_photo_paths TEXT[], p_no_issues BOOLEAN, p_note TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.lender_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
    IF b.status <> 'handed_over' OR p_no_issues IS NULL THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    PERFORM public.check_evidence_paths(b.id, p_return_photo_paths);
    INSERT INTO public.handover_records(booking_id, stage, recorded_by, item_photo_paths, no_issues, note)
        VALUES (b.id, 'return', auth.uid(), p_return_photo_paths, p_no_issues, p_note);
    UPDATE public.bookings SET status = 'returned', returned_at = NOW() WHERE id = b.id;
    RETURN jsonb_build_object('id', b.id, 'status', 'returned', 'returned_at', NOW());
END;
$$;
CREATE FUNCTION public.report_damage(p_booking_id UUID, p_description TEXT, p_photo_paths TEXT[], p_claimed_amount INTEGER)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings; v_id UUID;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.lender_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
    IF b.status <> 'returned' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF p_claimed_amount IS NULL OR p_claimed_amount < 0 OR coalesce(length(btrim(p_description)), 0) = 0 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    PERFORM public.check_evidence_paths(b.id, p_photo_paths);
    INSERT INTO public.damage_reports(booking_id, reported_by, description, photo_paths, claimed_amount)
        VALUES (b.id, auth.uid(), p_description, p_photo_paths, p_claimed_amount) RETURNING id INTO v_id;
    -- Plan section 5 reserves the booking's disputed transition for an admin.
    RETURN jsonb_build_object('report_id', v_id, 'status', 'open', 'booking_status', b.status);
END;
$$;
REVOKE ALL ON FUNCTION public.record_return(UUID, TEXT[], BOOLEAN, TEXT), public.report_damage(UUID, TEXT, TEXT[], INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_return(UUID, TEXT[], BOOLEAN, TEXT), public.report_damage(UUID, TEXT, TEXT[], INTEGER) TO authenticated;

CREATE FUNCTION public.confirm_receipt(p_booking_id UUID, p_ok BOOLEAN, p_note TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR b.borrower_id <> auth.uid() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
    IF b.status <> 'handed_over' OR b.receipt_confirmed_at IS NOT NULL THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF p_ok IS NULL THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    IF NOT p_ok AND coalesce(length(btrim(p_note)), 0) = 0 THEN RAISE EXCEPTION 'NOTE_REQUIRED'; END IF;
    INSERT INTO public.receipt_confirmations(booking_id, user_id, condition_ok, note) VALUES (b.id, auth.uid(), p_ok, p_note);
    UPDATE public.bookings SET receipt_confirmed_at = NOW() WHERE id = b.id;
    RETURN jsonb_build_object('id', b.id, 'status', b.status, 'receipt_confirmed_at', NOW(), 'condition_ok', p_ok);
END;
$$;
REVOKE ALL ON FUNCTION public.confirm_receipt(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_receipt(UUID, BOOLEAN, TEXT) TO authenticated;
