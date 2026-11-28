-- Build 0.4 (Phase 1). Additive: nothing from earlier migrations is edited.
-- 1. Soft delete for items (api-contract v1.0 section 6, delta 11).
-- 2. Public item cards with the Renter's first name (no exact address).
-- 3. get_public_settings (api-contract section 5.2).
-- 4. min_deposit_amount setting (delta 1, part 1): whitelist and cross-check.

ALTER TABLE public.items ADD COLUMN deleted_at TIMESTAMPTZ;

-- Deleted items are never public.
CREATE OR REPLACE FUNCTION public.item_is_public(p_item_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS(SELECT 1 FROM public.items i JOIN public.profiles p ON p.id = i.lender_id
        WHERE i.id = p_item_id AND i.status = 'active' AND i.deleted_at IS NULL
        AND p.status = 'active' AND p.kyc_status IN ('pending', 'verified'));
$$;

DROP POLICY items_select_visible ON public.items;
CREATE POLICY items_select_visible ON public.items FOR SELECT TO anon, authenticated
    USING ((lender_id = auth.uid() AND deleted_at IS NULL) OR public.item_is_public(id));
DROP POLICY items_update_own ON public.items;
CREATE POLICY items_update_own ON public.items FOR UPDATE TO authenticated
    USING (lender_id = auth.uid() AND deleted_at IS NULL AND public.is_active_user())
    WITH CHECK (lender_id = auth.uid() AND (status <> 'active' OR public.can_rent()));

-- Hard delete is replaced by delete_item (soft delete with booking checks).
DROP POLICY items_delete_own ON public.items;
REVOKE DELETE ON public.items FROM authenticated;

CREATE FUNCTION public.delete_item(p_item_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE i public.items;
BEGIN
    IF NOT public.is_active_user() THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    SELECT * INTO i FROM public.items WHERE id = p_item_id FOR UPDATE;
    IF NOT FOUND OR i.lender_id <> auth.uid() OR i.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'NOT_ALLOWED';
    END IF;
    -- Refused while an accepted-or-later booking exists (same set as the overlap constraint).
    IF EXISTS (SELECT 1 FROM public.bookings WHERE item_id = i.id AND status IN
        ('renter_accepted', 'awaiting_payment', 'payment_submitted', 'payment_verified',
         'handed_over', 'returned', 'disputed')) THEN
        RAISE EXCEPTION 'ACTIVE_BOOKINGS_EXIST';
    END IF;
    UPDATE public.bookings SET status = 'declined', decline_reason = 'item_deleted'
        WHERE item_id = i.id AND status = 'requested';
    UPDATE public.items SET deleted_at = NOW(), status = 'paused' WHERE id = i.id;
    RETURN jsonb_build_object('id', i.id, 'deleted', TRUE);
END;
$$;
REVOKE ALL ON FUNCTION public.delete_item(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_item(UUID) TO authenticated;

-- Public cards for Explore and Item details. Owner-run view on purpose: it joins
-- profiles (which anon cannot read) but exposes only the first name and only
-- rows that item_is_public() would show. No exact address, no phone.
CREATE VIEW public.public_items AS
    SELECT i.id, i.lender_id, i.title, i.description, i.daily_rate, i.declared_value,
        i.pickup_area, i.status, i.category, i.condition, i.rules, i.photo_paths, i.created_at,
        split_part(btrim(coalesce(p.display_name, '')), ' ', 1) AS lender_first_name
    FROM public.items i JOIN public.profiles p ON p.id = i.lender_id
    WHERE i.status = 'active' AND i.deleted_at IS NULL
        AND p.status = 'active' AND p.kyc_status IN ('pending', 'verified');
REVOKE ALL ON public.public_items FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.public_items TO anon, authenticated;

CREATE FUNCTION public.get_public_settings()
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT coalesce(jsonb_object_agg(key, value), '{}'::JSONB) FROM public.app_settings
    WHERE key IN ('commission_rate', 'deposit_rate', 'min_deposit_amount', 'late_fee_multiplier',
        'return_grace_hours', 'request_expiry_hours', 'min_declared_value');
$$;
REVOKE ALL ON FUNCTION public.get_public_settings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_settings() TO authenticated;

-- min_deposit_amount: whole NPR >= 0 and never above min_declared_value.
CREATE OR REPLACE FUNCTION public.validate_setting()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_number NUMERIC;
BEGIN
    IF NEW.key NOT IN ('commission_rate', 'deposit_rate', 'min_deposit_amount', 'late_fee_multiplier',
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
        IF NEW.key IN ('min_deposit_amount', 'min_declared_value') AND v_number <> trunc(v_number)
            THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_setting(p_key TEXT, p_value JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_before JSONB; v_other NUMERIC; v_new NUMERIC;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    -- Serializes missing-row inserts as well as existing-row changes.
    PERFORM pg_catalog.pg_advisory_xact_lock(624001);
    IF p_key IN ('min_deposit_amount', 'min_declared_value') AND jsonb_typeof(p_value) = 'number' THEN
        v_new := (p_value #>> '{}')::NUMERIC;
        SELECT (value #>> '{}')::NUMERIC INTO v_other FROM public.app_settings
            WHERE key = CASE p_key WHEN 'min_deposit_amount' THEN 'min_declared_value' ELSE 'min_deposit_amount' END
            AND jsonb_typeof(value) = 'number';
        IF v_other IS NOT NULL AND ((p_key = 'min_deposit_amount' AND v_new > v_other)
            OR (p_key = 'min_declared_value' AND v_new < v_other)) THEN
            RAISE EXCEPTION 'INVALID_VALUE';
        END IF;
    END IF;
    SELECT value INTO v_before FROM public.app_settings WHERE key = p_key FOR UPDATE;
    INSERT INTO public.app_settings(key, value) VALUES (p_key, p_value)
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'update_setting', p_key, v_before, p_value);
    RETURN jsonb_build_object('key', p_key, 'previous_value', v_before, 'value', p_value);
END;
$$;
