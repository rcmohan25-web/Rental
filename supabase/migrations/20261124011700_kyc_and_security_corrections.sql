UPDATE storage.buckets SET public=FALSE WHERE id IN ('kyc','handover','payment-proof');

CREATE FUNCTION public.submit_kyc(p_id_path TEXT,p_face_path TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.profiles; v_id UUID; v_path TEXT;
BEGIN
    SELECT * INTO p FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
    IF NOT FOUND OR p.status<>'active' THEN RAISE EXCEPTION 'ACCOUNT_RESTRICTED'; END IF;
    IF p.kyc_status NOT IN ('none','rejected') THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF p_id_path IS NULL OR p_face_path IS NULL OR p_id_path=p_face_path THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
    FOREACH v_path IN ARRAY ARRAY[p_id_path,p_face_path] LOOP
        IF split_part(v_path,'/',1)<>p.id::TEXT OR length(split_part(v_path,'/',2))=0
            OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='kyc' AND name=v_path)
            THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
    END LOOP;
    INSERT INTO public.kyc_submissions(user_id,id_path,face_path,submitted_at)
        VALUES(p.id,p_id_path,p_face_path,clock_timestamp()) RETURNING id INTO v_id;
    UPDATE public.profiles SET kyc_status='pending' WHERE id=p.id;
    RETURN jsonb_build_object('submission_id',v_id,'kyc_status','pending');
END;
$$;
CREATE FUNCTION public.get_my_kyc_status()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.profiles; k public.kyc_submissions;
BEGIN
    SELECT * INTO p FROM public.profiles WHERE id=auth.uid();
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
    SELECT * INTO k FROM public.kyc_submissions WHERE user_id=p.id AND status=p.kyc_status
        ORDER BY submitted_at DESC,id DESC LIMIT 1;
    RETURN jsonb_build_object('kyc_status',p.kyc_status,
        'reason',CASE WHEN p.kyc_status='rejected' AND k.status='rejected' THEN k.reason END,
        'submitted_at',k.submitted_at,'reviewed_at',k.reviewed_at);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_kyc(TEXT,TEXT),public.get_my_kyc_status() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT,TEXT),public.get_my_kyc_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_review_kyc(p_user_id UUID,p_decision TEXT,p_reason TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE k public.kyc_submissions; v_previous TEXT; v_path TEXT;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'NOT_ADMIN'; END IF;
    IF p_decision IS NULL OR p_decision NOT IN('verified','rejected') THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
    IF p_decision='rejected' AND coalesce(length(btrim(p_reason)),0)=0 THEN RAISE EXCEPTION 'REASON_REQUIRED'; END IF;
    SELECT kyc_status INTO v_previous FROM public.profiles WHERE id=p_user_id FOR UPDATE;
    SELECT * INTO k FROM public.kyc_submissions WHERE user_id=p_user_id AND status='pending' FOR UPDATE;
    IF NOT FOUND OR v_previous IS DISTINCT FROM 'pending' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;
    IF p_decision='verified' THEN
        FOREACH v_path IN ARRAY ARRAY[k.id_path,k.face_path] LOOP
            IF split_part(v_path,'/',1)<>p_user_id::TEXT
                OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='kyc' AND name=v_path)
                THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
        END LOOP;
    END IF;
    UPDATE public.kyc_submissions SET status=p_decision,reason=p_reason,reviewed_at=clock_timestamp(),reviewed_by=auth.uid() WHERE id=k.id;
    UPDATE public.profiles SET kyc_status=p_decision WHERE id=p_user_id;
    INSERT INTO public.audit_log(actor_id,action,target_id,before_value,after_value)
        VALUES(auth.uid(),'review_kyc',p_user_id::TEXT,jsonb_build_object('kyc_status',v_previous),
            jsonb_build_object('kyc_status',p_decision,'reason',p_reason,'submission_id',k.id));
    RETURN jsonb_build_object('user_id',p_user_id,'kyc_status',p_decision);
END;
$$;

-- Public helper reveals only whether the item is publicly visible, never profile data.
CREATE FUNCTION public.item_is_public(p_item_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS(SELECT 1 FROM public.items i JOIN public.profiles p ON p.id=i.lender_id
        WHERE i.id=p_item_id AND i.status='active' AND p.status='active' AND p.kyc_status IN('pending','verified'));
$$;
REVOKE ALL ON FUNCTION public.item_is_public(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.item_is_public(UUID) TO anon,authenticated;
DROP POLICY items_select_visible ON public.items;
CREATE POLICY items_select_visible ON public.items FOR SELECT TO anon,authenticated
    USING (lender_id=auth.uid() OR public.item_is_public(id));
CREATE POLICY items_admin_read ON public.items FOR SELECT TO authenticated USING(public.is_admin());

CREATE OR REPLACE FUNCTION public.validate_listing()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_min NUMERIC; v_path TEXT;
BEGIN
    IF NEW.status='active' THEN
        IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=NEW.lender_id AND status='active'
            AND kyc_status IN('pending','verified')) THEN RAISE EXCEPTION 'KYC_REQUIRED'; END IF;
        SELECT (value #>> '{}')::NUMERIC INTO v_min FROM public.app_settings
            WHERE key='min_declared_value' AND jsonb_typeof(value)='number';
        IF v_min IS NULL OR v_min<0 OR v_min<>trunc(v_min) THEN RAISE EXCEPTION 'SETTING_UNAVAILABLE'; END IF;
        IF NEW.daily_rate::TEXT IN('NaN','Infinity','-Infinity') OR NEW.daily_rate<>trunc(NEW.daily_rate)
            OR NEW.declared_value IS NULL OR NEW.declared_value::TEXT IN('NaN','Infinity','-Infinity')
            OR NEW.declared_value<>trunc(NEW.declared_value) OR NEW.declared_value<v_min
            OR coalesce(length(btrim(NEW.category)),0)=0 OR coalesce(length(btrim(NEW.condition)),0)=0
            OR cardinality(NEW.photo_paths) NOT BETWEEN 1 AND 5
            OR cardinality(NEW.photo_paths)<>(SELECT count(DISTINCT x) FROM unnest(NEW.photo_paths) x)
            THEN RAISE EXCEPTION 'INVALID_VALUE'; END IF;
        FOREACH v_path IN ARRAY NEW.photo_paths LOOP
            IF v_path IS NULL OR split_part(v_path,'/',1)<>NEW.lender_id::TEXT
                OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='item-photos' AND name=v_path)
                THEN RAISE EXCEPTION 'EVIDENCE_MISSING'; END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.item_photo_is_referenced(p_path TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT CASE WHEN auth.uid() IS NULL OR split_part(p_path,'/',1)<>auth.uid()::TEXT THEN TRUE
        ELSE EXISTS(SELECT 1 FROM public.items WHERE p_path=ANY(photo_paths)) END;
$$;
REVOKE ALL ON FUNCTION public.item_photo_is_referenced(TEXT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.item_photo_is_referenced(TEXT) TO authenticated;
-- Restrictive policies compose with existing uploader/account checks.
CREATE POLICY item_photo_preserve_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated
    USING(bucket_id<>'item-photos' OR NOT public.item_photo_is_referenced(name));
CREATE POLICY item_photo_preserve_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated
    USING(bucket_id<>'item-photos' OR NOT public.item_photo_is_referenced(name));

CREATE FUNCTION rental_private.notify_admin_issue()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    INSERT INTO public.notifications(user_id,booking_id,event)
        SELECT id,NEW.booking_id,TG_ARGV[0] FROM public.profiles WHERE role='admin' AND status='active';
    RETURN NEW;
END;
$$;
CREATE TRIGGER receipt_admin_attention AFTER INSERT ON public.receipt_confirmations
FOR EACH ROW WHEN (NOT NEW.condition_ok) EXECUTE FUNCTION rental_private.notify_admin_issue('receipt_disagreement');
CREATE TRIGGER return_admin_attention AFTER INSERT ON public.handover_records
FOR EACH ROW WHEN (NEW.stage='return' AND NEW.no_issues IS FALSE)
EXECUTE FUNCTION rental_private.notify_admin_issue('return_issue');
CREATE TRIGGER damage_admin_attention AFTER INSERT ON public.damage_reports
FOR EACH ROW EXECUTE FUNCTION rental_private.notify_admin_issue('damage_report');
-- Queue is derived from durable issue records, so an admin provisioned later can
-- still find issues. Resolution mechanics remain deferred, not client-writable.
CREATE VIEW public.admin_booking_attention WITH (security_invoker=TRUE) AS
    SELECT booking_id,'receipt_disagreement'::TEXT AS reason,confirmed_at AS created_at
        FROM public.receipt_confirmations WHERE NOT condition_ok AND public.is_admin()
    UNION ALL SELECT booking_id,'return_issue',recorded_at FROM public.handover_records
        WHERE stage='return' AND no_issues IS FALSE AND public.is_admin()
    UNION ALL SELECT booking_id,'damage_report',created_at FROM public.damage_reports
        WHERE status IN('open','escalated') AND public.is_admin();
REVOKE ALL ON public.admin_booking_attention FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.admin_booking_attention TO authenticated;
