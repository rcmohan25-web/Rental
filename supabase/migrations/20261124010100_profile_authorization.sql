ALTER TABLE public.profiles
    ADD COLUMN role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    ADD COLUMN status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    ADD COLUMN kyc_status TEXT NOT NULL DEFAULT 'none' CHECK (kyc_status IN ('none', 'pending', 'verified', 'rejected'));

CREATE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT EXISTS (SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin' AND status = 'active');
$$;
CREATE FUNCTION public.is_active_user()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT EXISTS (SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND status = 'active');
$$;
CREATE FUNCTION public.can_rent()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
        AND status = 'active' AND kyc_status IN ('pending', 'verified'));
$$;
REVOKE ALL ON FUNCTION public.is_admin(), public.is_active_user(), public.can_rent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(), public.is_active_user(), public.can_rent() TO authenticated;

DROP POLICY profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE TO authenticated
    USING (id = auth.uid() AND public.is_active_user()) WITH CHECK (id = auth.uid());
CREATE POLICY profiles_select_admin ON public.profiles FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY bookings_select_admin ON public.bookings FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY items_insert_own ON public.items;
CREATE POLICY items_insert_own ON public.items FOR INSERT TO authenticated
    WITH CHECK (lender_id = auth.uid() AND public.is_active_user()
        AND (status <> 'active' OR public.can_rent()));
DROP POLICY items_update_own ON public.items;
CREATE POLICY items_update_own ON public.items FOR UPDATE TO authenticated
    USING (lender_id = auth.uid() AND public.is_active_user())
    WITH CHECK (lender_id = auth.uid() AND (status <> 'active' OR public.can_rent()));
DROP POLICY items_delete_own ON public.items;
CREATE POLICY items_delete_own ON public.items FOR DELETE TO authenticated
    USING (lender_id = auth.uid() AND public.is_active_user());
