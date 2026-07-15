# SyncLedger — Flutter App

> A Flutter (Dart) client for the SyncLedger platform, compiled to both
> desktop web and native Android. Bridges the business owner (mobile) and
> the accounting staff (desktop) against a shared real-time Supabase backend.

This is one of three pieces of the SyncLedger product. See the top-level
[`../README.md`](../README.md) (when present) for the full picture, or:

- **`../syncledger-web/`** — Next.js web dashboard for accountants
- **Supabase project** — shared PostgreSQL backend, auth, storage, realtime

## Features

- **Invoices** — full lifecycle: draft → pending review → approved → paid, with
  vendor linking, status badges, PDF generation, and offline-first cache.
- **Document workspace** — split-panel viewer + side notes for the web build.
- **Contracts & payment phases** — contractors, contracts, allocated phases,
  with the remaining-unpaid balance surfaced in real time.
- **Purchase orders** — vendor-linked POs with line items and status tracking.
- **OCR bill scanning** — `google_mlkit_text_recognition` + `camera` on Android.
- **Biometric gate** — `local_auth` challenge on foreground/background transitions.
- **Offline mode** — Isar/sqflite cache with an offline banner and a queued
  mutation sync (`SyncService`).
- **Multi-language** — English, French, Arabic via Flutter's gen-l10n.
- **Light + dark theme** — Corporate Modern palette (Navy / Emerald / Soft
  Orange, Inter typography). Tokens live in `lib/core/theme/app_theme.dart`.

## Stack

| Layer | Tech |
|---|---|
| State | Riverpod (auto-dispose, families, stream providers) |
| Routing | go_router |
| Backend | Supabase (Postgres + Auth + Storage + Realtime) |
| Local cache | sqflite (offline mutation queue) + flutter_secure_storage |
| Native (Android) | camera, local_auth, google_mlkit_text_recognition, permission_handler |
| Notifications | firebase_messaging + flutter_local_notifications |
| Charts | fl_chart |
| PDF | pdf + printing |
| Typography | google_fonts (Inter) |

## Prerequisites

- Flutter SDK ≥ 3.3 (`flutter --version` to verify)
- Dart ≥ 3.3
- Android Studio + Android SDK (for Android build) / Xcode (for iOS, optional)
- A Supabase project (the `syncledger-web` setup_storage.js bootstraps the
  storage bucket; the SQL lives in `../syncledger-web/supabase/migrations/`)

## Environment

Create a `.env` file in the project root (this file is gitignored):

```env
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

These are read at compile time via `String.fromEnvironment`, so they must be
passed through your build command — see below.

> **Do not commit `.env`.** The repo's `.gitignore` already excludes it.

## Run

### Android (debug)

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### Web (debug, served on :8080)

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

The repo includes a small Node static server at the project root (`server.js`)
that serves the built `build/web` output with sane security headers
(CSP, X-Frame-Options, Referrer-Policy):

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
node server.js
# open http://localhost:8080
```

### Build a release APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

CI builds pass these values through GitHub Actions secrets — see the
`.github/workflows/` directory.

## Project structure

```
lib/
├── main.dart                    # entry: Supabase init + sync + router
├── core/                        # cross-cutting: theme, router, sync, db
│   ├── theme/                   # AppTheme (Corporate Modern) + provider
│   ├── router/                  # go_router config
│   ├── sync/                    # offline mutation sync worker
│   ├── database/                # sqflite helper + offline queue repo
│   ├── connectivity/            # connectivity_plus wrapper
│   ├── localization/            # locale provider
│   ├── notifications/           # FCM + local notifications
│   └── widgets/                 # shared widgets (haptic button, offline banner)
├── domain/                      # plain Dart models
├── features/                    # feature modules (auth, invoices, contracts, …)
│   └── <feature>/
│       ├── domain/              #   models
│       ├── data/                #   repositories (Supabase-backed)
│       └── presentation/        #   pages + providers + widgets
└── l10n/                        # ARB files: en, fr, ar
```

## Conventions

- **State**: one provider per feature, using `autoDispose` and `family` where
  appropriate. Stream providers for Supabase realtime channels.
- **Errors**: every async call in providers returns an `AsyncValue`; pages
  render loading / error / data states explicitly. No silent failures.
- **Theming**: always use `Theme.of(context).colorScheme.*` or
  `AppTheme.<token>`. Never hardcode hex values inside widgets.
- **i18n**: every user-visible string goes through `AppLocalizations.of(ctx)!`.

## Related

- **Design tokens** — `../DESIGN.md` (workspace root)
- **Web dashboard** — `../syncledger-web/`
- **Database migrations** — `../syncledger-web/supabase/migrations/`
