#!/usr/bin/env node
// Creates the GitHub labels and the Phase 0 / Phase 1 issues for Rental.
//
// Needs the GitHub CLI (https://cli.github.com) and `gh auth login` done once.
// Usage (from the repo root):
//   node scripts/setup_github.mjs --mohan <user> --smaran <user> --srijan <user>
//   node scripts/setup_github.mjs --dry-run          (prints the gh commands only)
// Optional: --repo owner/name   (default: the repo of the current folder)
// Safe to re-run: labels are updated and issues with the same title are skipped.

import { execFileSync } from 'node:child_process';

const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const dry = args.includes('--dry-run');
const repo = opt('repo');
const users = {
  mohan: opt('mohan'),
  smaran: opt('smaran'),
  srijan: opt('srijan'),
};

function gh(ghArgs) {
  const full = repo ? [...ghArgs, '--repo', repo] : ghArgs;
  if (dry) {
    console.log('gh ' + full.map((a) => JSON.stringify(a)).join(' '));
    return '';
  }
  return execFileSync('gh', full, { encoding: 'utf8' });
}

const labels = [
  ['task', '0E8A16', 'A piece of planned work'],
  ['bug', 'D73A4A', 'Something is broken'],
  ['backend-request', '5319E7', 'Ask Srijan for a schema, RLS or RPC change'],
  ['phase-0', 'C5DEF5', 'Skeleton and contracts'],
  ['phase-1', 'BFD4F2', 'Identity and listing'],
  ['phase-2', 'A2C4F2', 'Request to payment'],
  ['phase-3', '86B4EE', 'Handover, return and settlement'],
  ['phase-4', '6A9FEA', 'Automation and hardening'],
  ['phase-5', '4F8AE6', 'Release'],
];

const issues = [
  // ---------------- Phase 0 ----------------
  {
    owner: 'mohan',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] Protect main and finish repository settings',
    body: `Done when: main is protected and nobody can push to it directly.

- [ ] Smaran and Srijan accepted the collaborator invitation (Write)
- [ ] .github/CODEOWNERS has the real usernames and shows no error banner
- [ ] Ruleset imported from .github/rulesets/main-protection.json (or created by hand, see docs/setup/github-setup-mohan.md)
- [ ] Required check "Analyze and test" is listed
- [ ] Squash merge only, delete branch on merge
- [ ] Labels and Project board created`,
  },
  {
    owner: 'mohan',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] Everyone runs the skeleton on a phone and in Chrome',
    body: `Done when: Mohan, Smaran and Srijan each ran main on an Android device or emulator and the admin panel in Chrome.

- [ ] Mohan
- [ ] Smaran
- [ ] Srijan

Setup guide: docs/setup/machine-setup.md. Post any setup problem as a comment here.`,
  },
  {
    owner: 'mohan',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] Add the GitHub secrets once the Supabase projects exist',
    body: `Needs Srijan's rental-dev and rental-demo projects.

- [ ] SUPABASE_DEV_URL, SUPABASE_DEV_ANON_KEY
- [ ] SUPABASE_DEMO_URL, SUPABASE_DEMO_ANON_KEY
- [ ] SUPABASE_URL, SUPABASE_ANON_KEY (admin deploy)
- [ ] SUPABASE_DB_URL (session pooler string, for the weekly backup)
- [ ] CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID
- [ ] Run "Backup database" once and test a restore

Never add the service-role key to GitHub secrets.`,
  },
  {
    owner: 'smaran',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] money.dart and shared/fixtures/money_cases.json',
    body: `Owner: Smaran. Parity with SQL is checked by Srijan.

Rules (see docs/business-rules.md):
- days = end - start + 1 (inclusive); rental_fee = days x daily_price
- deposit = max(round(declared_value x deposit_rate), min_deposit_amount)   <- NEW: minimum fixed deposit set by the admin
- commission = rental_fee x commission_rate; renter_earning = rental_fee - commission
- borrower_pays_platform = rental_fee + deposit
- The renter pays no extra fee. Sapati's income is the commission.

Done when: money_cases.json has the worked example (declared 160,000, daily 3,500, 3 days = fee 10,500, deposit 40,000, pays 50,500, commission 1,050, earning 9,450), at least one low-value case where the minimum deposit applies, and the Dart unit tests pass.`,
  },
  {
    owner: 'smaran',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] Shared models and docs/api-contract.md (with Srijan)',
    body: `Write together, then freeze (changes need all three approvals).

- [ ] Models in packages/rental_data/lib/models: Booking, Item, Profile, Ledger, Terms (hand-written, equatable, fromJson/toJson)
- [ ] docs/api-contract.md: for each of the 16 RPCs the name, params, result, errors, caller and status transition
- [ ] Booking snapshot fields include commission_rate, deposit_rate, min_deposit_amount and the three terms version ids
- [ ] lender_id = Renter, borrower_id = Borrower`,
  },
  {
    owner: 'srijan',
    labels: ['task', 'phase-0'],
    title: '[Phase 0] Supabase projects, supabase init and first migration',
    body: `Owner: Srijan (single writer for supabase/). Guide: docs/setup/supabase-setup-srijan.md.

- [ ] Projects rental-dev and rental-demo created
- [ ] supabase init in supabase/, local stack runs with Docker
- [ ] First migration: profiles (sign-up trigger), items, bookings with the btree_gist double-booking constraint, app_settings, terms_documents
- [ ] app_settings seeded with the keys in docs/business-rules.md, including NEW min_deposit_amount
- [ ] bookings snapshot columns include min_deposit_amount
- [ ] db-ci workflow green; add "Migrations, lint and pgTAP" as a required check afterwards`,
  },
  {
    owner: 'srijan',
    labels: ['task', 'phase-0', 'backend-request'],
    title: '[Phase 0] Storage buckets and first RLS policies',
    body: `- [ ] Public bucket for item photos
- [ ] Private buckets: kyc, handover, payment-proof (images only, under 5 MB, uploader folder, signed URLs)
- [ ] RLS: clients cannot update role, status, kyc_status or money columns; a booking is readable only by its borrower, lender and admins
- [ ] Payment QR codes ship as app assets, no bucket needed`,
  },
  {
    owner: 'mohan',
    labels: ['task', 'phase-0'],
    title: '[Phase 0 gate] Agree the status machine and settings keys',
    body: `Everyone reviews docs/state-machine.md and docs/business-rules.md and comments "agreed" here.

Gate for Phase 0: CI green, every folder present, contract merged, first migration merged.`,
  },
  // ---------------- Phase 1 ----------------
  {
    owner: 'mohan',
    labels: ['task', 'phase-1'],
    title: '[Phase 1] Mobile auth: splash, landing, sign-up (optional ID step), login',
    body: `apps/mobile/lib/features/auth. Use the repository interfaces with fakes until Srijan's RPCs land.`,
  },
  {
    owner: 'mohan',
    labels: ['task', 'phase-1'],
    title: '[Phase 1] Profile, ID upload with consent notice and the ID gate guard',
    body: `apps/mobile/lib/features/profile_kyc. Show HonestyTexts.idConsentNotice and idMisuseWarning at upload. ID is required for everyone before the first request or listing.`,
  },
  {
    owner: 'mohan',
    labels: ['task', 'phase-1'],
    title: '[Phase 1] Admin role guard and ID verification queue',
    body: `apps/admin_web: shell/application/admin_guard.dart (role = admin only) and kyc_queue (signed URLs, approve or reject with reason).`,
  },
  {
    owner: 'smaran',
    labels: ['task', 'phase-1'],
    title: '[Phase 1] Explore and item details on fakes, then live data',
    body: `apps/mobile/lib/features/explore and item_details: category chips, search, filters, carousel, deposit shown separately, blocked dates, cost breakdown (uses money.dart).`,
  },
  {
    owner: 'srijan',
    labels: ['task', 'phase-1'],
    title: '[Phase 1] Profiles and items repositories, RLS review and add-listing flow',
    body: `rental_data Supabase repositories for profiles and items, then apps/mobile/lib/features/renter_listings (1 to 5 photos, declared value, rules, pickup area).`,
  },
];

console.log(dry ? 'DRY RUN: nothing is created.' : 'Creating labels and issues...');

for (const [name, color, description] of labels) {
  gh(['label', 'create', name, '--color', color, '--description', description, '--force']);
}

let existing = new Set();
if (!dry) {
  const listed = gh(['issue', 'list', '--state', 'all', '--limit', '300', '--json', 'title']);
  existing = new Set(JSON.parse(listed || '[]').map((i) => i.title));
}

for (const issue of issues) {
  if (existing.has(issue.title)) {
    console.log(`skip (exists): ${issue.title}`);
    continue;
  }
  const cmd = ['issue', 'create', '--title', issue.title, '--body', issue.body];
  for (const l of issue.labels) cmd.push('--label', l);
  const assignee = users[issue.owner];
  if (assignee) cmd.push('--assignee', assignee);
  const out = gh(cmd);
  if (out) console.log(out.trim());
}
console.log('Done.');
