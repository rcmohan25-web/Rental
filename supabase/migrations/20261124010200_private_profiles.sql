-- Keep public-facing profile state separate from personal/contact/payout data.
CREATE TABLE public.profile_private (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id),
    phone TEXT,
    area TEXT,
    payout_details JSONB NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(payout_details) = 'object'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.profile_private ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_private FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profile_private TO authenticated;
GRANT INSERT (user_id, phone, area, payout_details) ON public.profile_private TO authenticated;
GRANT UPDATE (phone, area, payout_details) ON public.profile_private TO authenticated;
CREATE POLICY private_profile_read ON public.profile_private FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY private_profile_insert ON public.profile_private FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND public.is_active_user());
CREATE POLICY private_profile_update ON public.profile_private FOR UPDATE TO authenticated
    USING (user_id = auth.uid() AND public.is_active_user()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER private_profile_updated BEFORE UPDATE ON public.profile_private
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.kyc_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id),
    id_path TEXT NOT NULL,
    face_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    reason TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id),
    CHECK (id_path <> face_path),
    CHECK (status <> 'rejected' OR (reason IS NOT NULL AND length(btrim(reason)) > 0))
);
CREATE UNIQUE INDEX kyc_one_pending ON public.kyc_submissions(user_id) WHERE status = 'pending';
ALTER TABLE public.kyc_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kyc_submissions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.kyc_submissions TO authenticated;
CREATE POLICY kyc_admin_read ON public.kyc_submissions FOR SELECT TO authenticated USING (public.is_admin());
-- Upload/submission entry point is deferred until its supplemental RPC contract is approved.
