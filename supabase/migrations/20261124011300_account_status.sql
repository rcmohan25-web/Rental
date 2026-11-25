-- Actual deletion/anonymization is blocked on the retention design. Keep Auth FK.
CREATE FUNCTION public.admin_set_user_status(p_user_id UUID, p_status TEXT, p_reason TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.profiles;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_status IS NULL OR p_status NOT IN ('active', 'suspended') THEN RAISE EXCEPTION 'DELETION_NOT_APPROVED'; END IF;
    IF coalesce(length(btrim(p_reason)), 0) = 0 THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
    SELECT * INTO p FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    IF p.role = 'admin' THEN RAISE EXCEPTION 'CANNOT_TARGET_ADMIN'; END IF;
    IF p.status = 'deleted' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    UPDATE public.profiles SET status = p_status WHERE id = p.id;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'set_user_status', p.id::TEXT,
            jsonb_build_object('status', p.status), jsonb_build_object('status', p_status, 'reason', p_reason));
    RETURN jsonb_build_object('user_id', p.id, 'status', p_status);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_user_status(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_status(UUID, TEXT, TEXT) TO authenticated;
