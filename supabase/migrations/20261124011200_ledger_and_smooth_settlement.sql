CREATE TABLE public.ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    kind TEXT NOT NULL CHECK (kind IN ('lender_earning', 'deposit_refund')),
    amount NUMERIC(16,2) NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL DEFAULT 'due' CHECK (status IN ('on_hold', 'due', 'paid')),
    reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    UNIQUE (booking_id, kind),
    CHECK (status <> 'paid' OR (paid_at IS NOT NULL AND reference IS NOT NULL AND length(btrim(reference)) > 0))
);
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ledger_entries FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ledger_entries TO authenticated;
CREATE POLICY ledger_read ON public.ledger_entries FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

CREATE FUNCTION public.settle_booking(p_booking_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE b public.bookings;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF b.status = 'completed' AND (SELECT count(*) FROM public.ledger_entries WHERE booking_id = b.id) = 2 THEN
        RETURN jsonb_build_object('id', b.id, 'status', 'completed', 'already_settled', TRUE);
    END IF;
    IF b.status <> 'returned' OR b.snapshot_recorded_at IS NULL OR b.returned_at IS NULL THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF EXISTS (SELECT 1 FROM public.damage_reports WHERE booking_id = b.id AND status <> 'resolved')
        OR EXISTS (SELECT 1 FROM public.receipt_confirmations WHERE booking_id = b.id AND NOT condition_ok)
        OR NOT EXISTS (SELECT 1 FROM public.handover_records WHERE booking_id = b.id AND stage = 'return' AND no_issues)
        THEN RAISE EXCEPTION 'OPEN_CASE_EXISTS'; END IF;
    -- Only the unambiguously on-time path is implemented. Even within-grace late
    -- dates wait for agreement on the exact grace boundary and late-fee rules.
    IF (b.returned_at AT TIME ZONE 'Asia/Kathmandu')::DATE > b.end_date THEN RAISE EXCEPTION 'LATE_RULE_NOT_APPROVED'; END IF;
    INSERT INTO public.ledger_entries(booking_id, user_id, kind, amount) VALUES
        (b.id, b.lender_id, 'lender_earning', b.lender_earning),
        (b.id, b.borrower_id, 'deposit_refund', b.deposit_amount);
    UPDATE public.bookings SET status = 'completed' WHERE id = b.id;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'settle_booking', b.id::TEXT, to_jsonb(b.status), to_jsonb('completed'::TEXT));
    RETURN jsonb_build_object('id', b.id, 'status', 'completed', 'already_settled', FALSE);
END;
$$;
REVOKE ALL ON FUNCTION public.settle_booking(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.settle_booking(UUID) TO authenticated;
