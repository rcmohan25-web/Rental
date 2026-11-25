ALTER TABLE public.items
    ADD COLUMN category TEXT,
    ADD COLUMN condition TEXT,
    ADD COLUMN rules TEXT,
    ADD COLUMN photo_paths TEXT[] NOT NULL DEFAULT '{}';
GRANT INSERT (category, condition, rules, photo_paths) ON public.items TO authenticated;
GRANT UPDATE (category, condition, rules, photo_paths) ON public.items TO authenticated;
CREATE INDEX items_explore_idx ON public.items(status, category, pickup_area);

CREATE FUNCTION public.validate_listing()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_min NUMERIC; v_path TEXT;
BEGIN
    -- Legacy active rows are not rewritten; eligibility is checked on their next write.
    IF NEW.status = 'active' THEN
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.lender_id
            AND status = 'active' AND kyc_status IN ('pending', 'verified')) THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
        SELECT (value #>> '{}')::NUMERIC INTO v_min FROM public.app_settings
            WHERE key = 'min_declared_value' AND jsonb_typeof(value) = 'number';
        IF v_min IS NULL THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
        IF NEW.declared_value IS NULL OR NEW.declared_value < v_min
            OR coalesce(length(btrim(NEW.category)), 0) = 0
            OR coalesce(length(btrim(NEW.condition)), 0) = 0
            OR cardinality(NEW.photo_paths) NOT BETWEEN 1 AND 5 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        FOREACH v_path IN ARRAY NEW.photo_paths LOOP
            IF v_path IS NULL OR split_part(v_path, '/', 1) <> NEW.lender_id::TEXT
                OR length(split_part(v_path, '/', 2)) = 0 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER items_validate_listing BEFORE INSERT OR UPDATE ON public.items
    FOR EACH ROW EXECUTE FUNCTION public.validate_listing();

CREATE TABLE public.item_pickup_details (
    item_id UUID PRIMARY KEY REFERENCES public.items(id) ON DELETE CASCADE,
    exact_address TEXT NOT NULL CHECK (length(btrim(exact_address)) > 0),
    instructions TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.item_pickup_details ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.item_pickup_details FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.item_pickup_details TO authenticated;
GRANT INSERT (item_id, exact_address, instructions) ON public.item_pickup_details TO authenticated;
GRANT UPDATE (exact_address, instructions) ON public.item_pickup_details TO authenticated;
CREATE POLICY pickup_owner_read ON public.item_pickup_details FOR SELECT TO authenticated
    USING (public.is_admin() OR EXISTS (SELECT 1 FROM public.items i WHERE i.id = item_id AND i.lender_id = auth.uid()));
CREATE POLICY pickup_owner_insert ON public.item_pickup_details FOR INSERT TO authenticated
    WITH CHECK (public.is_active_user() AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = item_id AND i.lender_id = auth.uid()));
CREATE POLICY pickup_owner_update ON public.item_pickup_details FOR UPDATE TO authenticated
    USING (public.is_active_user() AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = item_id AND i.lender_id = auth.uid()));
CREATE TRIGGER pickup_updated BEFORE UPDATE ON public.item_pickup_details
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
-- Borrower contact delivery is deferred to the approved gated-contact interface.
