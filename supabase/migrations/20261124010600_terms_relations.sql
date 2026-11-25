ALTER TABLE public.terms_documents
    ADD COLUMN audience TEXT CHECK (audience IN ('general', 'borrower', 'renter')),
    ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN archived_at TIMESTAMPTZ,
    ADD CONSTRAINT active_terms_published CHECK (NOT is_active OR (status = 'published' AND audience IS NOT NULL));
CREATE UNIQUE INDEX terms_one_active_audience ON public.terms_documents(audience) WHERE is_active;
CREATE UNIQUE INDEX terms_audience_version ON public.terms_documents(audience, version) WHERE audience IS NOT NULL;
CREATE TABLE public.booking_terms (
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    audience TEXT NOT NULL CHECK (audience IN ('general', 'borrower', 'renter')),
    terms_document_id UUID NOT NULL REFERENCES public.terms_documents(id),
    PRIMARY KEY (booking_id, audience),
    UNIQUE (booking_id, audience, terms_document_id)
);
CREATE TABLE public.terms_acceptances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    role TEXT NOT NULL CHECK (role IN ('borrower', 'renter')),
    terms_document_id UUID NOT NULL,
    accepted_version TEXT NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    app_version TEXT NOT NULL CHECK (length(btrim(app_version)) > 0),
    FOREIGN KEY (booking_id, role, terms_document_id)
        REFERENCES public.booking_terms(booking_id, audience, terms_document_id),
    UNIQUE (booking_id, role, user_id, terms_document_id)
);
ALTER TABLE public.booking_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terms_acceptances ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.booking_terms, public.terms_acceptances FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booking_terms, public.terms_acceptances TO authenticated;
CREATE POLICY booking_terms_read ON public.booking_terms FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));
CREATE POLICY acceptances_read ON public.terms_acceptances FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));
CREATE POLICY terms_history_read ON public.terms_documents FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.booking_terms bt WHERE bt.terms_document_id = id));
CREATE POLICY terms_admin_read ON public.terms_documents FOR SELECT TO authenticated USING (public.is_admin());

CREATE FUNCTION public.guard_terms_document()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF OLD.status <> 'draft' OR OLD.published_at IS NOT NULL THEN
        IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'TERMS_IMMUTABLE'; END IF;
        IF ROW(NEW.title, NEW.version, NEW.content, NEW.audience, NEW.published_at)
            IS DISTINCT FROM ROW(OLD.title, OLD.version, OLD.content, OLD.audience, OLD.published_at)
            OR NEW.status = 'draft' THEN RAISE EXCEPTION 'TERMS_IMMUTABLE'; END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER terms_guard BEFORE UPDATE OR DELETE ON public.terms_documents
    FOR EACH ROW EXECUTE FUNCTION public.guard_terms_document();

CREATE FUNCTION public.validate_booking_terms()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN RAISE EXCEPTION 'TERMS_IMMUTABLE'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.terms_documents t JOIN public.bookings b ON b.id = NEW.booking_id
        WHERE t.id = NEW.terms_document_id AND t.audience = NEW.audience AND t.status <> 'draft'
        AND t.id = ANY(b.terms_version_ids)) THEN RAISE EXCEPTION 'TERMS_VERSION_MISMATCH'; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER booking_terms_validate BEFORE INSERT OR UPDATE OR DELETE ON public.booking_terms
    FOR EACH ROW EXECUTE FUNCTION public.validate_booking_terms();

CREATE FUNCTION public.validate_acceptance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN RAISE EXCEPTION 'TERMS_IMMUTABLE'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.bookings b JOIN public.terms_documents t ON t.id = NEW.terms_document_id
        WHERE b.id = NEW.booking_id AND t.version = NEW.accepted_version
        AND NEW.user_id = CASE NEW.role WHEN 'renter' THEN b.lender_id ELSE b.borrower_id END)
        THEN RAISE EXCEPTION 'TERMS_VERSION_MISMATCH'; END IF;
    NEW.accepted_at := NOW();
    RETURN NEW;
END;
$$;
CREATE TRIGGER acceptance_validate BEFORE INSERT OR UPDATE OR DELETE ON public.terms_acceptances
    FOR EACH ROW EXECUTE FUNCTION public.validate_acceptance();

CREATE FUNCTION public.admin_publish_terms(p_audience TEXT, p_body TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id UUID; v_version TEXT; v_old UUID;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_audience IS NULL OR p_audience NOT IN ('general', 'borrower', 'renter')
        OR coalesce(length(btrim(p_body)), 0) = 0 THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(624002);
    -- Retain text storage; increment numeric versions within this audience.
    SELECT (coalesce(max(version::NUMERIC), 0) + 1)::TEXT INTO v_version
        FROM public.terms_documents WHERE audience = p_audience AND version ~ '^[0-9]+$';
    SELECT id INTO v_old FROM public.terms_documents WHERE audience = p_audience AND is_active FOR UPDATE;
    UPDATE public.terms_documents SET is_active = FALSE, status = 'archived', archived_at = NOW() WHERE id = v_old;
    INSERT INTO public.terms_documents(title, version, content, status, audience, is_active, published_at)
        VALUES (p_audience || ' terms', v_version, p_body, 'published', p_audience, TRUE, NOW()) RETURNING id INTO v_id;
    INSERT INTO public.audit_log(actor_id, action, target_id, before_value, after_value)
        VALUES (auth.uid(), 'publish_terms', p_audience, jsonb_build_object('id', v_old), jsonb_build_object('id', v_id));
    RETURN jsonb_build_object('id', v_id, 'version', v_version, 'audience', p_audience);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_publish_terms(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_publish_terms(TEXT, TEXT) TO authenticated;
