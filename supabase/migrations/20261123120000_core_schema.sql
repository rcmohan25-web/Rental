-- =============================================================================
-- Phase 0, migration 1 of 4: core schema
-- Owner: Srijan.  Tables: profiles, items, bookings, app_settings, terms_documents
--
-- What is here
--   * extensions (btree_gist is needed for the double-booking constraint)
--   * helper trigger function set_updated_at()
--   * the five Phase 0 tables with constraints and indexes
--   * the sign-up trigger that creates a profile for every new auth user
--   * reference data every environment needs: app_settings and terms v1
--
-- Security (RLS, grants) is in migration 2, storage in migration 3.
-- Naming: in code and database "lender_id" is the Renter, "borrower_id" the Borrower.
-- Dates are date-only and are interpreted in Asia/Kathmandu.
-- =============================================================================

create extension if not exists btree_gist with schema extensions;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Today's date in Nepal. Used for "no past dates" checks and blocked-date queries.
create or replace function public.today_kathmandu()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Kathmandu')::date;
$$;

-- -----------------------------------------------------------------------------
-- profiles
-- One row per person. Same id as auth.users.id.
--
-- There is deliberately NO foreign key to auth.users. Account deletion is a soft
-- delete (request_account_deletion anonymises the row) and the Edge Function then
-- removes the auth user. Bookings and the ledger must keep pointing at a profile
-- row, so the profile has to outlive the auth user. The sign-up trigger below is
-- what keeps the two tables in step.
-- -----------------------------------------------------------------------------

create table public.profiles (
  id                   uuid primary key,
  role                 text not null default 'user'
                         check (role in ('user', 'admin')),
  status               text not null default 'active'
                         check (status in ('active', 'suspended', 'deleted')),
  full_name            text check (char_length(full_name) between 1 and 100),
  phone                text check (char_length(phone) between 5 and 20),
  area                 text check (area in ('Kathmandu', 'Lalitpur', 'Bhaktapur')),
  -- ID verification ("Verified" means checked by an admin, nothing automatic)
  kyc_status           text not null default 'not_submitted'
                         check (kyc_status in ('not_submitted', 'pending', 'verified', 'rejected')),
  kyc_id_path          text,   -- path inside the private kyc-documents bucket
  kyc_face_path        text,   -- path inside the private kyc-documents bucket
  kyc_rejection_reason text,
  kyc_submitted_at     timestamptz,
  kyc_reviewed_at      timestamptz,
  deleted_at           timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

comment on table public.profiles is
  'One row per person (same id as auth.users). Role, status and kyc_* columns are written only by RPCs.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Sign-up trigger: every new auth user gets a profile automatically.
-- The app passes full_name, phone and area as sign-up metadata. role and status
-- are NEVER read from metadata (users can edit their own metadata).
-- It must never fail, because a failing trigger blocks sign-up, so bad input is
-- cleaned up instead of rejected.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name  text := left(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 100);
  v_phone text := left(nullif(btrim(coalesce(new.raw_user_meta_data ->> 'phone', new.phone)), ''), 20);
  v_area  text := nullif(btrim(new.raw_user_meta_data ->> 'area'), '');
begin
  if v_area is not null and v_area not in ('Kathmandu', 'Lalitpur', 'Bhaktapur') then
    v_area := null;
  end if;
  if v_phone is not null and char_length(v_phone) < 5 then
    v_phone := null;
  end if;

  insert into public.profiles (id, full_name, phone, area)
  values (new.id, v_name, v_phone, v_area)
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- items
-- A listing created by a Renter (lender). Rows are never hard-deleted:
-- "delete" sets status = 'deleted' so old bookings keep their item.
-- Photos are stored as paths inside the public item-photos bucket.
-- -----------------------------------------------------------------------------

create table public.items (
  id             uuid primary key default gen_random_uuid(),
  lender_id      uuid not null references public.profiles (id),
  title          text not null check (char_length(title) between 3 and 100),
  category       text not null
                   check (category in ('camera', 'projector', 'gaming', 'camping',
                                       'tools', 'music', 'electronics', 'other')),
  description    text not null default '' check (char_length(description) <= 2000),
  condition      text not null
                   check (condition in ('new', 'like_new', 'good', 'fair')),
  daily_price    numeric(12, 2) not null check (daily_price > 0),
  declared_value numeric(12, 2) not null check (declared_value > 0),  -- deposit is a % of this
  rules          text not null default '' check (char_length(rules) <= 1000),
  area           text not null check (area in ('Kathmandu', 'Lalitpur', 'Bhaktapur')),
  photo_paths    text[] not null
                   check (cardinality(photo_paths) between 1 and 5),
  status         text not null default 'active'
                   check (status in ('active', 'paused', 'deleted')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on table public.items is
  'Listings. Soft delete only (status = deleted). Exact pickup address lives in item_pickup_details (later phase).';

create index items_lender_idx on public.items (lender_id);
create index items_explore_idx on public.items (status, area, category);

create trigger items_set_updated_at
  before update on public.items
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- bookings
-- One row per rental request. The status only changes through RPCs.
--
-- Money columns are a SNAPSHOT taken when the request is created, so changing the
-- price or the admin settings later never changes an existing booking.
--
-- Double booking: the exclusion constraint makes it impossible for two bookings
-- of the same item to hold overlapping dates while they are in a "date-blocking"
-- status. A plain "requested" booking does not block dates (many people may ask
-- for the same days); the Renter's Accept is what reserves them. The database
-- enforces this even when two accepts arrive at the same moment.
-- End date is INCLUSIVE: 6 to 8 Nov is 3 days.
-- -----------------------------------------------------------------------------

create table public.bookings (
  id                   uuid primary key default gen_random_uuid(),
  item_id              uuid not null references public.items (id),
  lender_id            uuid not null references public.profiles (id),
  borrower_id          uuid not null references public.profiles (id),
  start_date           date not null,
  end_date             date not null,
  days                 integer generated always as (end_date - start_date + 1) stored,
  status               text not null default 'requested'
                         check (status in (
                           'requested', 'declined', 'expired', 'cancelled',
                           'renter_accepted', 'awaiting_payment', 'payment_submitted',
                           'payment_verified', 'handed_over', 'returned',
                           'completed', 'disputed')),
  -- snapshot of money and rules at request time
  daily_price          numeric(12, 2) not null check (daily_price > 0),
  rental_fee           numeric(12, 2) not null check (rental_fee >= 0),
  deposit_amount       numeric(12, 2) not null check (deposit_amount >= 0),
  commission_rate      numeric(5, 4)  not null check (commission_rate between 0 and 1),
  deposit_rate         numeric(5, 4)  not null check (deposit_rate between 0 and 1),
  terms_version_ids    uuid[] not null default '{}',
  -- workflow details
  decline_reason       text,
  expires_at           timestamptz,       -- a still-requested booking expires at this time
  receipt_confirmed_at timestamptz,       -- Borrower confirmed receipt (status stays handed_over)
  is_overdue           boolean not null default false,  -- derived flag set by a scheduled job
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint bookings_dates_valid     check (end_date >= start_date),
  constraint bookings_not_own_item    check (borrower_id <> lender_id),
  -- must mirror money.dart: fee = days x daily price
  constraint bookings_fee_matches_days
    check (rental_fee = (end_date - start_date + 1) * daily_price),

  constraint bookings_no_double_booking
    exclude using gist (
      item_id with =,
      daterange(start_date, end_date, '[]') with &&
    )
    where (status in (
      'renter_accepted', 'awaiting_payment', 'payment_submitted',
      'payment_verified', 'handed_over', 'returned', 'disputed', 'completed'))
);

comment on table public.bookings is
  'Rental requests. Written only by SECURITY DEFINER RPCs; clients can only read their own.';
comment on constraint bookings_no_double_booking on public.bookings is
  'No two date-blocking bookings of one item may overlap (end date inclusive).';

create index bookings_item_idx     on public.bookings (item_id);
create index bookings_borrower_idx on public.bookings (borrower_id, status);
create index bookings_lender_idx   on public.bookings (lender_id, status);

create trigger bookings_set_updated_at
  before update on public.bookings
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- app_settings
-- Business knobs that admins can change in Rental Admin without a release.
-- Values are jsonb so one table holds numbers and flags. Changes go through
-- admin_update_setting (Phase 2) which also writes the audit log.
-- -----------------------------------------------------------------------------

create table public.app_settings (
  key         text primary key check (key ~ '^[a-z][a-z0-9_]*$'),
  value       jsonb not null,
  description text not null default '',
  updated_by  uuid references public.profiles (id) on delete set null,
  updated_at  timestamptz not null default now(),

  constraint app_settings_rates_are_fractions check (
    key not in ('commission_rate', 'deposit_rate')
    or case when jsonb_typeof(value) = 'number'
            then (value #>> '{}')::numeric between 0 and 1
            else false end
  ),
  constraint app_settings_flags_are_boolean check (
    key <> 'auto_approve_orders' or jsonb_typeof(value) = 'boolean'
  ),
  constraint app_settings_expiry_is_positive_number check (
    key <> 'request_expiry_hours'
    or case when jsonb_typeof(value) = 'number'
            then (value #>> '{}')::numeric > 0
            else false end
  )
);

comment on table public.app_settings is
  'Admin-editable business settings. Booking rows snapshot the values they need.';

create trigger app_settings_set_updated_at
  before update on public.app_settings
  for each row execute function public.set_updated_at();

-- PLACEHOLDER VALUES. The business notes decide the real rates. Admins can
-- change them in Rental Admin; existing bookings keep the value they started with.
insert into public.app_settings (key, value, description) values
  ('commission_rate',     '0.10', 'PLACEHOLDER: platform commission as a fraction of the rental fee (0.10 = 10%).'),
  ('deposit_rate',        '0.25', 'PLACEHOLDER: refundable deposit as a fraction of the item declared value (0.25 = 25%).'),
  ('auto_approve_orders', 'true', 'When true, an order moves to awaiting_payment automatically once both IDs are verified.'),
  ('request_expiry_hours','48',   'A request nobody answers expires after this many hours.')
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- terms_documents
-- Three term sets (general, borrower, renter). Each has numbered versions and
-- exactly one active version. A published version is immutable, because
-- bookings remember which version ids applied (bookings.terms_version_ids).
-- New versions are published through admin_publish_terms (Phase 2).
-- -----------------------------------------------------------------------------

create table public.terms_documents (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('general', 'borrower', 'renter')),
  version      integer not null check (version > 0),
  title        text not null check (char_length(title) between 3 and 150),
  body         text not null check (char_length(body) > 0),
  is_active    boolean not null default false,
  published_by uuid references public.profiles (id) on delete set null,
  published_at timestamptz,
  created_at   timestamptz not null default now(),
  unique (kind, version)
);

-- at most one active version per kind
create unique index terms_documents_one_active_per_kind
  on public.terms_documents (kind) where is_active;

comment on table public.terms_documents is
  'Versioned terms and conditions (prototype templates, not legal advice). Only is_active and published_* may change after insert.';

create or replace function public.terms_documents_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'terms_immutable' using errcode = 'P0001',
      hint = 'Published terms cannot be deleted. Publish a new version instead.';
  end if;

  if (new.kind, new.version, new.title, new.body)
     is distinct from (old.kind, old.version, old.title, old.body) then
    raise exception 'terms_immutable' using errcode = 'P0001',
      hint = 'Published terms cannot be edited. Publish a new version instead.';
  end if;
  return new;
end;
$$;

create trigger terms_documents_guard
  before update or delete on public.terms_documents
  for each row execute function public.terms_documents_guard();

-- Version 1 of each set. TEMPLATES: a supervisor or legal adviser must review
-- them before any real use (honesty rule 5). No specific law is named (rule 8).
insert into public.terms_documents (kind, version, title, body, is_active, published_at) values
('general', 1, 'General Terms (prototype)',
$terms$Prototype terms, not legal advice. To be reviewed by a legal adviser before real use.

1. About Rental. Rental is a prototype marketplace run by Sapati. It connects people who lend items (Renters) with people who borrow them (Borrowers) in the Kathmandu Valley. Sapati does not own the items.
2. Accounts. Give true information and keep your login private. One person may hold one account.
3. Identity checks. "Verified" means an administrator checked your ID by hand. No automatic face matching is used.
4. Identity misuse. Using another person's ID, submitting a false or altered document or photo, or letting someone else use your verified account is misuse of identity. It can lead to account suspension and may be punishable according to the law.
5. Manual payments. Payments are made outside the app (eSewa, Khalti or bank transfer) and checked by an administrator. There is no payment gateway, escrow or insurance.
6. Payouts and refunds. They are recorded in the app but paid outside it by an administrator.
7. Acceptance. Ticking a box records your acceptance. It is not a certified electronic signature.
8. Changes. Sapati may publish new versions of these terms. A booking keeps the versions that applied when it was requested.$terms$,
 true, now()),
('borrower', 1, 'Borrower Terms (prototype)',
$terms$Prototype terms, not legal advice. To be reviewed by a legal adviser before real use.

1. Payment first. You pay the rental fee and the refundable deposit shown in your booking before the item is handed over. Payment is manual and checked by an administrator.
2. Handover. You receive a handover code after your payment is verified. Give it to the Renter only when you meet and collect the item. The Renter will photograph the item and may ask to see your original ID.
3. Care of the item. Use the item carefully and only for its normal purpose. Do not lend it on to anyone else.
4. Return. Return the item on the agreed end date in the condition you received it. Late returns may cost extra at the rate shown in the app when you requested.
5. Damage or loss. If the item is damaged or not returned, the deposit may be used to cover the loss and you may be asked to pay more. An administrator decides disputes using the recorded evidence.
6. Deposit refund. After the return is checked, the deposit is refunded or reduced as decided. The refund is recorded in the app and paid outside it.
7. Cancelling. You may cancel a request before you pay.$terms$,
 true, now()),
('renter', 1, 'Renter Terms (prototype)',
$terms$Prototype terms, not legal advice. To be reviewed by a legal adviser before real use.

1. Accurate listing. Describe the item honestly, including its condition, and give a fair declared value. Photos must show the real item.
2. Accepting a request. Accept only if the item will be available on the requested dates. Accepting reserves those dates.
3. Handover. Hand the item over only after the app shows the payment as verified and the Borrower gives the correct handover code. Record photos and the checklist at handover.
4. Return. Check the item on return and record photos. Report any damage promptly with evidence.
5. Earnings. After a rental is completed you receive the rental fee minus Sapati's commission at the rate shown in the app when the request was made. Payouts are recorded in the app and paid outside it.
6. Identity. Do not copy or share the Borrower's ID photo or any personal details from the handover.$terms$,
 true, now());
