Role: You are a Principal Application Security Engineer, DevSecOps Specialist, and Senior Penetration Tester. Your objective is to perform an exhaustive security review and threat model for "SyncLedger" (user-facing brand: "Equinox"), a dual-client business financial management platform.

---

### 1. PLATFORM ARCHITECTURE & TECH STACK
*   **Web Client:** Next.js 16.2.10 (App Router, SSR, React 19.2.4) utilizing `@supabase/ssr` (v0.12.0) for session persistence via HTTP-only cookies.
*   **Mobile Client:** Flutter 3.27.4 (Dart SDK ≥3.3.0) using `supabase_flutter` (v2.8.4).
*   **Local Mobile Storage:** `shared_preferences` (for general cache) and `sqflite` (v2.4.1) for offline SQLite caching and mutation queuing[cite: 1].
*   **Backend:** Supabase (PostgreSQL 15+) with Row-Level Security (RLS) enabled on all tables[cite: 1].
*   **Edge Functions (Deno):** Handles privileged owner-only actions: `create-staff`, `delete-staff`, and `reset-staff-password`[cite: 1].
*   **Offline Sync Engine:** A Dart `SyncService` that queues pending mutations (INSERT/UPDATE/DELETE) in a local `sync_queue` table and replays them when connectivity returns[cite: 1].

---

### 2. SPECIFIC THREAT VECTORS & KNOWN DEBT TO AUDIT
I need you to deeply analyze and write threat scenarios, exploit pathways, and precise code fixes for the following areas:

#### A. Network, Port, & Connection Security
1. **Supabase Client Exposure:** The web client's `.env.local` and the mobile client's `main.dart` have hardcoded Supabase credentials, including the `supabaseAnonKey`[cite: 1]. Is there any way an attacker can abuse this key to bypass RLS, perform denial of service (DoS), or scrape public metadata?
2. **Reverse Proxy & Self-Hosting Ports:** A `server.js` file is present for self-hosting a Flutter web build on port 8080[cite: 1]. If self-hosted, how should this port be protected? What are the risks of running it without a reverse proxy (e.g., Nginx) or a Web Application Firewall (WAF)?
3. **Missing SSL Pinning:** The Flutter app utilizes standard HTTP clients (`Dio`/`Http`) without SSL/TLS certificate pinning[cite: 1]. Outline a detailed Man-in-the-Middle (MitM) scenario where an attacker on a compromised local network intercepts and alters DZD financial transaction payloads.

#### B. Supabase & PostgreSQL Security (Backend & Edge Functions)
1. **Edge Function Privilege Escalation:** The Deno Edge Functions handle admin/owner tasks like `create-staff` and `delete-staff`[cite: 1]. How can we verify that these functions strictly authenticate user roles and prevent JWT spoofing or unauthorized invocation? 
2. **Row-Level Security (RLS) Bypasses:** With tables like `invoices`, `audit_logs`, and `cash_registers`[cite: 1], what are the common PostgreSQL RLS pitfalls we must avoid? Ensure the `audit_logs` table remains strictly INSERT-only and cannot be tampered with via SQL injection or compromised JWTs[cite: 1].
3. **Migration Artifact Leakage:** The migration files contain placeholders like `YOUR_PROJECT_REF` and `YOUR_SERVICE_ROLE_KEY`[cite: 1]. If left unreplaced or committed to GitHub, how severe is the risk?

#### C. Mobile Client & Offline Engine Hardening (Flutter)
1. **Unobfuscated Release Builds:** The APK is built via GitHub Actions (`flutter build apk --release`) without `--obfuscate` or `--split-debug-info`[cite: 1]. Show me how an attacker can reverse-engineer this package to extract our API endpoints, offline database schemas, and hardcoded keys[cite: 1].
2. **SQLite and SharedPreferences Data Leakage:** The app caches financial overviews and lists locally using `shared_preferences` and unencrypted `sqflite` databases[cite: 1]. If a device is stolen, physical access is gained, or another malicious app is installed on the device, how easily can this cache be read?
3. **Offline Mutation Replay Exploits:** The `SyncService` replays queued mutations when connectivity resumes[cite: 1]. How could an attacker manipulate the local SQLite queue (`sync_queue`) to replay unauthorized data changes or bypass backend RLS checks once the app goes back online[cite: 1]?

#### D. Next.js Web Dashboard Vulnerabilities
1. **Hydration Data Leaks:** Because we use Next.js App Router and SSR[cite: 1], how can we prevent Next.js from accidentally serializing and leaking sensitive database fields (like hashes or internal IDs) into the `__NEXT_DATA__` hydration JSON in the browser page source?
2. **Session Hijacking & CSRF:** We use `@supabase/ssr` with HTTP-only cookies[cite: 1]. Walk through the optimal security flags (`Secure`, `SameSite`, `HttpOnly`) required to block Cross-Site Scripting (XSS) token theft and Cross-Site Request Forgery (CSRF).

---

### 3. ACTIONABLE OUTPUT REQUIREMENTS
For every risk you identify, provide:
1. **Vulnerability Name & Severity** (Critical, High, Medium, Low).
2. **Exploit Scenario:** A realistic walkthrough of how a malicious actor would target SyncLedger[cite: 1].
3. **The 'Why':** The technical mechanics of the weakness.
4. **Step-by-Step Remediation:** Exact Dart/Flutter code, Next.js configuration, or Supabase PostgreSQL SQL queries required to patch the security gap.

---

Acknowledge your role, and let me know you are ready. I will then provide the specific files (such as `main.dart`, `middleware.ts`, SQLite helpers, or SQL schema migrations) that you request[cite: 1].