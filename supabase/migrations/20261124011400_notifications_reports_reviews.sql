CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    booking_id UUID REFERENCES public.bookings(id),
    event TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);
CREATE INDEX notifications_user_created ON public.notifications(user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;
CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notifications_mark_read ON public.notifications FOR UPDATE TO authenticated
    USING (user_id = auth.uid() AND public.is_active_user()) WITH CHECK (user_id = auth.uid());
CREATE FUNCTION public.notify_booking_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO public.notifications(user_id, booking_id, event) VALUES
            (NEW.lender_id, NEW.id, 'booking_' || NEW.status),
            (NEW.borrower_id, NEW.id, 'booking_' || NEW.status);
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER booking_notify AFTER INSERT OR UPDATE OF status ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.notify_booking_status();
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id),
    item_id UUID REFERENCES public.items(id),
    reported_user_id UUID REFERENCES public.profiles(id),
    reason TEXT NOT NULL CHECK (length(btrim(reason)) > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (num_nonnulls(item_id, reported_user_id) = 1)
);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reports FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.reports TO authenticated;
GRANT INSERT (reporter_id, item_id, reported_user_id, reason) ON public.reports TO authenticated;
CREATE POLICY reports_read ON public.reports FOR SELECT TO authenticated
    USING (reporter_id = auth.uid() OR public.is_admin());
CREATE POLICY reports_insert ON public.reports FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid() AND public.is_active_user());

-- Rating scale, public visibility and client write contract need Smaran's approval.
-- This private table is a foundation, not an enabled review submission endpoint.
CREATE TABLE public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id),
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id),
    target_user_id UUID NOT NULL REFERENCES public.profiles(id),
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (booking_id, reviewer_id),
    CHECK (reviewer_id <> target_user_id)
);
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.reviews TO authenticated;
CREATE POLICY reviews_private_read ON public.reviews FOR SELECT TO authenticated
    USING (reviewer_id = auth.uid() OR target_user_id = auth.uid() OR public.is_admin());

CREATE SCHEMA IF NOT EXISTS rental_private;
REVOKE ALL ON SCHEMA rental_private FROM PUBLIC, anon, authenticated;
CREATE FUNCTION rental_private.expire_requests()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count INTEGER;
BEGIN
    UPDATE public.bookings SET status = 'expired'
        WHERE status = 'requested' AND expires_at IS NOT NULL AND expires_at <= NOW();
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION rental_private.expire_requests() FROM PUBLIC, anon, authenticated;
-- Worker is not scheduled yet: expiry values are not approved/seeded and
-- request creation is deferred. No overdue/escalation deadlines are invented.
