
-- ============================================================
-- RENTAL BY SAPATI
-- PHASE 0: INITIAL DATABASE SCHEMA
-- Owner: Srijan
-- ============================================================
-- Includes:
-- 1. Profiles and automatic sign-up trigger
-- 2. Rental items
-- 3. Bookings and double-booking protection
-- 4. Application settings
-- 5. Terms documents
-- 6. Initial Row Level Security policies
-- 7. Storage buckets and initial access policies
--
-- Booking statuses follow docs/state-machine.md.
-- Additional workflow rules will be enforced through RPCs.
-- ============================================================


-- ============================================================
-- 1. REQUIRED EXTENSION
-- ============================================================

-- Allows equality comparisons on UUID values inside
-- a PostgreSQL GiST exclusion constraint.

CREATE EXTENSION IF NOT EXISTS btree_gist;


-- ============================================================
-- 2. USER PROFILES
-- ============================================================

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    display_name TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- Automatically create a profile when a new user signs up.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        display_name
    )
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data ->> 'display_name'
    );

    RETURN NEW;
END;
$$;


CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();


-- Profiles security

ALTER TABLE public.profiles
ENABLE ROW LEVEL SECURITY;


-- Users may read their own profile.

CREATE POLICY "profiles_select_own"
ON public.profiles
FOR SELECT
TO authenticated
USING (
    id = (SELECT auth.uid())
);


-- Users may update their own profile.

CREATE POLICY "profiles_update_own"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    id = (SELECT auth.uid())
)
WITH CHECK (
    id = (SELECT auth.uid())
);


-- Profile creation happens through the Auth trigger.
-- No direct client INSERT or DELETE policies are provided.


-- ============================================================
-- 3. RENTAL ITEMS
-- ============================================================

CREATE TABLE public.items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Item owner (called Renter in the UI).
    lender_id UUID NOT NULL
        REFERENCES public.profiles(id),

    title TEXT NOT NULL
        CHECK (length(trim(title)) > 0),

    description TEXT,

    daily_rate NUMERIC(12, 2) NOT NULL
        CHECK (daily_rate > 0),

    declared_value NUMERIC(12, 2)
        CHECK (
            declared_value IS NULL
            OR declared_value >= 0
        ),

    pickup_area TEXT NOT NULL
        CHECK (length(trim(pickup_area)) > 0),

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'active',
                'paused'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Used to ensure the booking's lender
    -- matches the actual item owner.
    CONSTRAINT items_id_lender_unique
        UNIQUE (id, lender_id)
);


-- Index for listing items by owner.

CREATE INDEX items_lender_idx
ON public.items(lender_id);


-- Items security

ALTER TABLE public.items
ENABLE ROW LEVEL SECURITY;


-- Everyone may view active listings.
-- Owners may also view their own inactive listings.

CREATE POLICY "items_select_visible"
ON public.items
FOR SELECT
TO anon, authenticated
USING (
    status = 'active'
    OR lender_id = (SELECT auth.uid())
);


-- Authenticated owners may create their own items.

CREATE POLICY "items_insert_own"
ON public.items
FOR INSERT
TO authenticated
WITH CHECK (
    lender_id = (SELECT auth.uid())
);


-- Owners may update their own items.

CREATE POLICY "items_update_own"
ON public.items
FOR UPDATE
TO authenticated
USING (
    lender_id = (SELECT auth.uid())
)
WITH CHECK (
    lender_id = (SELECT auth.uid())
);


-- Owners may delete their own items.
-- Existing booking references prevent deletion
-- while dependent booking records remain.

CREATE POLICY "items_delete_own"
ON public.items
FOR DELETE
TO authenticated
USING (
    lender_id = (SELECT auth.uid())
);


-- ============================================================
-- 4. BOOKINGS
-- ============================================================

-- Booking statuses from Mohan's state machine:
--
-- requested
-- declined
-- expired
-- cancelled
-- renter_accepted
-- awaiting_payment
-- payment_submitted
-- payment_verified
-- handed_over
-- returned
-- completed
-- disputed
--
-- Status transitions must be controlled by RPCs.
-- Clients are not given direct write policies.


CREATE TABLE public.bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    item_id UUID NOT NULL,

    lender_id UUID NOT NULL,

    borrower_id UUID NOT NULL
        REFERENCES public.profiles(id),

    start_date DATE NOT NULL,

    end_date DATE NOT NULL,

    status TEXT NOT NULL DEFAULT 'requested'
        CHECK (
            status IN (
                'requested',
                'declined',
                'expired',
                'cancelled',
                'renter_accepted',
                'awaiting_payment',
                'payment_submitted',
                'payment_verified',
                'handed_over',
                'returned',
                'completed',
                'disputed'
            )
        ),

    -- Rates saved at booking time.
    commission_rate NUMERIC(5, 4) NOT NULL DEFAULT 0,

    deposit_rate NUMERIC(5, 4) NOT NULL DEFAULT 0,

    -- IDs of the terms versions recorded at booking.
    terms_version_ids UUID[] NOT NULL DEFAULT '{}',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- End date is inclusive.
    CONSTRAINT valid_booking_dates
        CHECK (end_date >= start_date),

    -- Borrower cannot rent their own item.
    CONSTRAINT cannot_book_own_item
        CHECK (lender_id <> borrower_id),

    CONSTRAINT valid_commission_rate
        CHECK (commission_rate BETWEEN 0 AND 1),

    CONSTRAINT valid_deposit_rate
        CHECK (deposit_rate BETWEEN 0 AND 1),

    -- A booking must reference the real item owner.
    CONSTRAINT booking_item_owner_fk
        FOREIGN KEY (item_id, lender_id)
        REFERENCES public.items(id, lender_id)
);


-- ============================================================
-- 5. DOUBLE-BOOKING PROTECTION
-- ============================================================

-- The same item cannot have overlapping accepted
-- or ongoing reservations.
--
-- Multiple unapproved requests may exist.
--
-- Dates are inclusive:
-- Nov 24 to Nov 26 occupies all three days.
-- Another booking can begin on Nov 27.

ALTER TABLE public.bookings
ADD CONSTRAINT prevent_double_booking
EXCLUDE USING gist (
    item_id WITH =,
    daterange(start_date, end_date, '[]') WITH &&
)
WHERE (
    status IN (
        'renter_accepted',
        'awaiting_payment',
        'payment_submitted',
        'payment_verified',
        'handed_over',
        'returned',
        'disputed'
    )
);


-- Index for looking up a user's bookings.

CREATE INDEX bookings_borrower_idx
ON public.bookings(borrower_id);

CREATE INDEX bookings_lender_idx
ON public.bookings(lender_id);


-- ============================================================
-- 6. BOOKINGS SECURITY
-- ============================================================

ALTER TABLE public.bookings
ENABLE ROW LEVEL SECURITY;


-- Only the borrower and item owner
-- may read a booking directly.

CREATE POLICY "bookings_select_participants"
ON public.bookings
FOR SELECT
TO authenticated
USING (
    borrower_id = (SELECT auth.uid())
    OR lender_id = (SELECT auth.uid())
);


-- No direct client INSERT, UPDATE or DELETE policies.
-- Booking creation and status changes will use
-- controlled RPC functions in later migrations.


-- ============================================================
-- 7. APPLICATION SETTINGS
-- ============================================================

CREATE TABLE public.app_settings (
    key TEXT PRIMARY KEY,

    value JSONB NOT NULL,

    description TEXT,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


ALTER TABLE public.app_settings
ENABLE ROW LEVEL SECURITY;


-- No direct client access initially.
-- Admin settings will use authorized RPC functions.


-- ============================================================
-- 8. TERMS DOCUMENTS
-- ============================================================

CREATE TABLE public.terms_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title TEXT NOT NULL,

    version TEXT NOT NULL,

    content TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'published',
                'archived'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    published_at TIMESTAMPTZ,

    CONSTRAINT unique_terms_version
        UNIQUE (title, version)
);


ALTER TABLE public.terms_documents
ENABLE ROW LEVEL SECURITY;


-- Everyone may read published terms.

CREATE POLICY "terms_select_published"
ON public.terms_documents
FOR SELECT
TO anon, authenticated
USING (
    status = 'published'
);


-- Creating, editing and publishing terms
-- will use authorized admin functions.


-- ============================================================
-- 9. SUPABASE STORAGE BUCKETS
-- ============================================================

-- Storage bucket names are proposed for Phase 0.
-- Confirm naming with the team before freezing them.
--
-- Item photos are public.
-- KYC, handover and payment proof remain private.


INSERT INTO storage.buckets (
    id,
    name,
    public
)
VALUES
    ('item-photos', 'item-photos', TRUE),
    ('kyc', 'kyc', FALSE),
    ('handover', 'handover', FALSE),
    ('payment-proof', 'payment-proof', FALSE)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- 10. PUBLIC ITEM PHOTO POLICIES
-- ============================================================

-- Public users may view item photos.

CREATE POLICY "item_photos_public_read"
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
    bucket_id = 'item-photos'
);


-- Users upload into their own user-ID folder:
--
-- item-photos/<user-id>/filename.jpg

CREATE POLICY "item_photos_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'item-photos'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- Users can update photos in their own folder.

CREATE POLICY "item_photos_update_own"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'item-photos'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
)
WITH CHECK (
    bucket_id = 'item-photos'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- Users can delete their own uploaded photos.

CREATE POLICY "item_photos_delete_own"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'item-photos'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- ============================================================
-- 11. PRIVATE KYC STORAGE POLICIES
-- ============================================================

-- Example:
-- kyc/<user-id>/document.jpg
--
-- A user can upload and view their own KYC files.
-- Other users cannot read them.

CREATE POLICY "kyc_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'kyc'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


CREATE POLICY "kyc_select_own"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'kyc'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- No direct client UPDATE or DELETE policies.
-- Admin review access will be implemented separately.


-- ============================================================
-- 12. PRIVATE HANDOVER STORAGE POLICIES
-- ============================================================

-- Example:
-- handover/<user-id>/evidence.jpg

CREATE POLICY "handover_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'handover'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


CREATE POLICY "handover_select_own"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'handover'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- Participant and admin evidence access
-- will be handled through later security rules.


-- ============================================================
-- 13. PRIVATE PAYMENT PROOF STORAGE POLICIES
-- ============================================================

-- Example:
-- payment-proof/<user-id>/receipt.jpg

CREATE POLICY "payment_proof_insert_own"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'payment-proof'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


CREATE POLICY "payment_proof_select_own"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'payment-proof'
    AND (storage.foldername(name))[1]
        = (SELECT auth.uid())::TEXT
);


-- Admin payment verification access
-- will be implemented separately.


-- ============================================================
-- END OF PHASE 0 INITIAL MIGRATION
-- ============================================================

-- Remaining work:
-- 1. Implement and test booking RPCs.
-- 2. Enforce the full booking status machine.
-- 3. Add admin authorization and ID verification checks.
-- 4. Add sensitive-column access controls.
-- 5. Add evidence and payment metadata tables.
-- 6. Add complete storage participant/admin access rules.
-- 7. Add automated database and security tests.
-- 8. Finalize the model with Mohan and Smaran.
