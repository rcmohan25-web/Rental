-- RLS controls rows; grants separately control available operations/columns.
REVOKE ALL ON public.profiles, public.items, public.bookings,
    public.app_settings, public.terms_documents FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profiles, public.bookings TO authenticated;
GRANT UPDATE (display_name) ON public.profiles TO authenticated;
GRANT SELECT ON public.items, public.terms_documents TO anon, authenticated;
GRANT INSERT (lender_id, title, description, daily_rate, declared_value,
    pickup_area, status) ON public.items TO authenticated;
GRANT UPDATE (title, description, daily_rate, declared_value, pickup_area, status)
    ON public.items TO authenticated;
GRANT DELETE ON public.items TO authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- New objects created by this migration owner are private until explicitly granted.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
