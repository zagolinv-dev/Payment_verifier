# T's Verify

Ethiopian payment verification and multi-wallet reconciliation platform. Waiters scan payment receipts via OCR, verify them against expected amounts, and managers get dashboards with KPI tracking.

## Tech Stack

- **Mobile:** Flutter 3.10+ / Dart 3.x
- **Backend:** Node.js / Express (Ethiopia-hosted for bank verification)
- **Admin Portal:** Next.js
- **Database & Auth:** Supabase (PostgreSQL + Edge Functions)

## Prerequisites

- Flutter SDK >= 3.10
- Dart SDK >= 3.0
- Node.js >= 18
- A Supabase project (free tier works)

## Setup

### 1. Environment Variables

Copy the template and fill in your Supabase credentials:

```bash
cp .env.example .env
```

Required variables:
- `SUPABASE_URL` — Your Supabase project URL
- `SUPABASE_ANON_KEY` — Your Supabase anonymous key

### 2. Supabase

Run the migration files in order to set up the database schema:

```bash
# Connect to your Supabase project and run:
supabase_migration_final.sql    # Core tables and RLS
supabase_add_superadmin_role.sql
supabase_fix_data_isolation.sql
supabase_fix_cafe_isolation_rls.sql
supabase_fix_superadmin_and_notifications.sql
supabase_fix_superadmin_select.sql
supabase_fix_transaction_delete.sql
fix_recursion.sql
```

### 3. Backend Server

```bash
cd backend
npm install
# Must be hosted on a server IN ETHIOPIA for CBE/BOA verification to work
npm start
```

### 4. Mobile App

```bash
cd payment_verifier
flutter pub get
flutter run
```

### 5. Build for Release

```bash
# Generate a keystore (keep this file secure, never commit it):
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload

# Create android/key.properties with:
# storePassword=<password>
# keyPassword=<password>
# keyAlias=upload
# storeFile=../upload-keystore.jks

# Build app bundle:
flutter build appbundle --release

# Or APK:
flutter build apk --release
```

## Architecture

```
lib/
├── core/          # Constants, theme, router, utils
├── domain/        # Entities, repository interfaces
├── data/          # Datasources, models, repository implementations, services
└── presentation/  # Screens, providers, widgets
```

## Supported Banks

- Commercial Bank of Ethiopia (CBE)
- Bank of Abyssinia (BOA)
- Telebirr
- Awash Bank
- CBE Birr

## License

Private — All rights reserved.
