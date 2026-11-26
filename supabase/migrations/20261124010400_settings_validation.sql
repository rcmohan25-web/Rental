-- No settings are seeded: business values still need approval.
CREATE FUNCTION public.validate_setting()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_number NUMERIC;
BEGIN
    IF NEW.key NOT IN ('commission_rate', 'deposit_rate', 'late_fee_multiplier',
        'return_grace_hours', 'legal_action_period_days', 'request_expiry_hours',
        'min_declared_value', 'auto_approve_orders') THEN RAISE EXCEPTION 'INVALID_KEY'; END IF;
    IF NEW.key = 'auto_approve_orders' THEN
        IF jsonb_typeof(NEW.value) <> 'boolean' THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    ELSE
        IF jsonb_typeof(NEW.value) <> 'number' THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        v_number := (NEW.value #>> '{}')::NUMERIC;
        IF v_number < 0 OR (NEW.key IN ('commission_rate', 'deposit_rate') AND v_number > 1)
            OR (NEW.key IN ('request_expiry_hours', 'legal_action_period_days') AND v_number <= 0)
            THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        IF NEW.key IN ('commission_rate', 'deposit_rate') AND v_number <> round(v_number, 4)
            THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER app_settings_validate BEFORE INSERT OR UPDATE ON public.app_settings
    FOR EACH ROW EXECUTE FUNCTION public.validate_setting();
GRANT SELECT ON public.app_settings TO authenticated;
CREATE POLICY settings_admin_read ON public.app_settings FOR SELECT TO authenticated USING (public.is_admin());

CREATE FUNCTION public.admin_update_setting(p_key TEXT, p_value JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_before JSONB;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    -- Serializes missing-row inserts as well as existing-row changes.
    PERFORM pg_catalog.pg_advisory_xact_lock(624001);
    SELECT value INTO v_before FROM public.app_settings WHERE key = p_key FOR UPDATE;
    INSERT INTO public.app_settings(key, value) VALUES (p_key, p_value)
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'update_setting', p_key, v_before, p_value);
    RETURN jsonb_build_object('key', p_key, 'previous_value', v_before, 'value', p_value);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_setting(TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_setting(TEXT, JSONB) TO authenticated;
