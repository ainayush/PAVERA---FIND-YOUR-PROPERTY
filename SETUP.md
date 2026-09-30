# Pavera

A responsive Expo / React Native property marketplace. This deployment starts in a clearly labelled **isolated local demo workspace**, not a live real-estate marketplace. Sample listings are illustrative. No sample conversation is delivered to a real seller. No payment success is simulated.

## Run and build

- `npm install` only when dependencies need restoration.
- Type check: `npx tsc --noEmit`.
- Production assets for every platform: `npx expo export --platform all`.
- The web output is `dist/`.

## What works without credentials

Browse eight sample property types/locations; filter/sort; image detail navigation and full-screen galleries; local likes, saves, comments, reports; share/deep links for seeded listings; multi-image device uploads with validation, primary-photo/reorder/delete; full listing draft, preview, publish, edit and lifecycle; editable demo profile and imagery; local conversations and image attachments; notifications; seller dashboard; isolated moderation preview; light/dark/system theme. Local demo state uses AsyncStorage and is never inserted into the production database. New local listings are not shareable across devices until connected to a backend.

## Connect secure accounts and shared data

1. Create a Supabase project. Run `supabase/migrations/001_marketplace.sql` once on a new database; review the policies for your deployment.
2. Enable email confirmation, configure SMTP delivery, and add your HTTPS deployment plus native deep-link callbacks to the Auth allowlist.
3. Copy `.env.example` to `.env`. Fill only the Supabase URL, publishable key and public site URL, then rebuild. Never include the service-role key or Razorpay secrets in any `EXPO_PUBLIC_*` variable.
4. The migration creates tables, validated relationships, RLS, owner-scoped image uploads, private conversation policies, notification triggers, and Realtime publication for messages / notifications / payments. The client handles account login, signup, password recovery and session persistence. Native sessions use SecureStore; web sessions use browser storage (serve with a restrictive CSP and audit dependencies).
5. Create real users through email-verified signup. A trusted operator assigns an admin by inserting their UUID into `admins` and setting that profile's role to `Admin` from a privileged SQL session. Admin signup is never public. Demo admin preview cannot access production admin data.
6. Moderation approval and verification are separate operator actions. Review ownership/identity documentation through your legal verification process before verifying a live property. The app does not perform automated identity verification.

## Payments: explicit configuration required

1. Configure a Razorpay merchant account and begin with **test credentials**.
2. Set `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` and `APP_ORIGIN` with Supabase server secrets. No secret is included in the app bundle.
3. Deploy `create-payment` with JWT verification; deploy `payment-webhook` without Supabase JWT verification (it verifies the gateway HMAC signature itself). See `supabase/config.toml`.
4. Configure the webhook endpoint for `payment_link.paid`, `payment_link.expired`, `payment_link.cancelled` and `refund.processed`. Provide the exact matching webhook secret.
5. Only verified, active, real listings accept booking initialization. The server reads the amount from the database, authenticates the buyer, validates the fields, rejects self-booking, checks duplicates and throttles requests, then creates a Razorpay hosted Payment Link. Amounts are in paise server-side.
6. A created gateway link produces a **Pending**, not Successful, payment. Only a verified matching webhook updates success/refund status. Gateway event IDs are processed atomically and idempotently by a service-role-only SQL function. Receipts use the resulting real payment record. An expired link becomes Failed only upon its verified event. Interrupted initialization can require operator reconciliation: never blindly retry or mark it successful.
7. Set operational refund policies, booking contracts, GST/receipt requirements, seller settlements, KYC, reconciliation and customer support procedures before collecting funds. This integration records bookings; it does **not** transfer a property title or automatically settle to sellers.

## Production release checklist (requires configured services)

- Run integration tests using at least a buyer, seller, unrelated user and admin; attempt forbidden reads, ownership changes, privilege escalation, conversation-member changes and forged payment updates.
- Verify email confirmation, login/logout, recovery links (web and native), session expiry and account deletion policy.
- Test image MIME, size, path ownership, image privacy requirements and an antivirus/content-moderation pipeline appropriate to your business.
- Verify message delivery, recipient read state, multiple devices and offline failures with Realtime.
- Test gateway success, user cancellation, expired links, retry, replayed/forged webhooks, amount mismatch, full refunds and out-of-order events. Never use demo output as proof of payment integration testing.
- Obtain a legal review for real-estate regulations, privacy/retention policy, terms, refunds, seller verification and handling of private addresses.
- Add deployment-specific observability, backups, retention, rate limiting/WAF and accessibility/native-device testing. Admin user suspension/deletion should be handled through privileged Supabase account operations until your organization's audited user-administration service is integrated.
- Review `npm audit`; the scaffold includes upstream moderate findings. Do not use `--force` without compatibility testing.

## Scope honesty

The UI and local workflows are functional and deployable. Live account delivery, remote storage, multi-user chat and actual money movement cannot be validated without operator credentials. Backend migrations and payment functions are provided for integration and require staging/security review before production use. No deployed backend, SMS provider, automated KYC, settlement system or real seller contact is claimed. Categories are provisioned in the schema; custom category administration can be performed by a trusted admin in the database.
