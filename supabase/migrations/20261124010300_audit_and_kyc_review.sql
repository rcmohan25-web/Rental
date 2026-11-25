CREATE TABLE public.audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id UUID NOT NULL REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    target_id TEXT NOT NULL,
    before_value JSONB,
    after_value JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.audit_log FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.audit_log TO authenticated;
CREATE POLICY audit_admin_read ON public.audit_log FOR SELECT TO authenticated USING (public.is_admin());

CREATE FUNCTION public.admin_review_kyc(p_user_id UUID, p_decision TEXT, p_reason TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_submission public.kyc_submissions; v_previous TEXT;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_decision IS NULL OR p_decision NOT IN ('verified', 'rejected') THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    IF p_decision = 'rejected' AND coalesce(length(btrim(p_reason)), 0) = 0 THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
    SELECT kyc_status INTO v_previous FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    SELECT * INTO v_submission FROM public.kyc_submissions WHERE user_id = p_user_id AND status = 'pending' FOR UPDATE;
    IF NOT FOUND OR v_previous <> 'pending' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    UPDATE public.kyc_submissions SET status = p_decision, reason = p_reason,
        reviewed_at = NOW(), reviewed_by = auth.uid() WHERE id = v_submission.id;
    UPDATE public.profiles SET kyc_status = p_decision WHERE id = p_user_id;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'review_kyc', p_user_id::TEXT,
            jsonb_build_object('kyc_status', v_previous), jsonb_build_object('kyc_status', p_decision));
    RETURN jsonb_build_object('user_id', p_user_id, 'kyc_status', p_decision);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_review_kyc(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc(UUID, TEXT, TEXT) TO authenticated;
