# Pairnest

**Better Money, Happier Together.** A couples' budgeting and emotional-wellness app with shared budgets, savings goals, private mood check-ins, guided money talks and date planning. A bird-pair mascot and five shared themes (Sage Green, Ocean Blue, Lavender, Peach, Midnight) give it a friendly look.

```
app/      Flutter app (Android, iOS, Web)
backend/  Laravel 12 API (PHP 8.2+, MySQL or SQLite)
deploy/   Oracle Cloud Always Free provisioning + deploy scripts
```

## Accounts: no email, no password

Pairnest doesn't collect email addresses or passwords. Onboarding asks for a first name (plus optional answers about your relationship, goals and money style, which become starter savings goals and the first budget) and creates an anonymous account: a token kept on the phone.

- **Pairing:** one partner creates the nest and shares the 6-letter invite code; the other joins with it.
- **New or lost phone:** on the partner's phone, Us → Personalize → *Re-link a phone* shows a one-time code (10 minutes). On the new phone, tap *I already have a nest* and enter it.
- **Recovery key:** shown once after onboarding (and re-issuable in Personalize). It also gets you back in. Pairnest only stores a hash of it; if both the key and your partner's phone are gone, the nest can't be recovered.
- Recovery and re-link attempts are rate-limited (5 per minute per IP).

## Run the app with demo data

No backend is needed. Without `API_URL` the app uses in-memory demo data (Alex & Sam).

```bash
cd app
flutter pub get
flutter run -d chrome            # tap "Explore the demo nest", or answer the onboarding questions
```

To open the app through XAMPP's Apache at `http://localhost/Pairnest/app/build/web/`, build it for that folder, or the page stays blank (it looks for its files at `http://localhost/`):

```bash
flutter build web --base-href /Pairnest/app/build/web/   # in Git Bash, prefix with MSYS_NO_PATHCONV=1
```

Rebuild after every change; `flutter run -d chrome` needs no build step.

`tool/preview_main.dart` boots straight into the signed-in demo so each screen opens by URL. Build it with `flutter build web -t tool/preview_main.dart -o build/preview`, then open `/#/goals` or `/?theme=midnight#/home`.

## Run against the local API (XAMPP)

```bash
cd backend
php artisan migrate:fresh --seed     # local env seeds Alex & Sam; recovery keys DEMO-ALEX-0000-NEST / DEMO-SAMM-0000-NEST
php artisan serve --port=8800

cd ../app
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8800/api/v1
# Android emulator: --dart-define=API_URL=http://10.0.2.2:8800/api/v1
```

The backend `.env` uses SQLite by default. To use XAMPP's MySQL instead, create a `pairnest` database and set `DB_CONNECTION=mysql` and the `DB_*` values in `backend/.env`.

## Tests

```bash
cd backend && php artisan test                      # API: pairing, privacy, budget math, scoping
cd app && flutter analyze && flutter test           # models, theming, navigation, every screen renders
# Contract test: Flutter ApiRepository against the live API
cd app && flutter test test/api_contract_test.dart --dart-define=API_URL=http://127.0.0.1:8800/api/v1
```

## API overview (`/api/v1`)

| Area | Endpoints |
|---|---|
| Auth | `POST auth/register`, `POST auth/login`, `POST auth/logout`, `GET auth/me` |
| Nest | `POST couple` (create), `POST couple/join` `{code}`, `GET couple`, `PATCH couple` `{theme}` |
| Money | `GET dashboard`, `GET/POST transactions`, `PATCH/DELETE transactions/{id}`, `GET/PUT budgets/{YYYY-MM}` |
| Goals | `GET/POST goals`, `PATCH/DELETE goals/{id}`, `POST goals/{id}/contributions` |
| Feelings | `GET/POST moods`, `DELETE moods/{id}` (private moods are never shown to the partner) |
| Talks | `GET talks/current`, `POST talks/current/answer`, `GET talks/history` (partner's answer is revealed after you answer) |
| Plans | `GET/POST plans`, `PATCH/DELETE plans/{id}` |

All data is scoped to the signed-in user's couple. Every route except auth and creating or joining a nest returns `409` until the user has a nest.

## Deploy to Oracle Cloud Always Free

The whole stack runs on one free VM. Nginx serves the Flutter web build at `/` and the Laravel API at `/api`. Because both are on the same origin, no CORS setup is needed.

1. **Create the VM.** In OCI, go to *Compute → Instances → Create*, choose image **Canonical Ubuntu 24.04** and shape **VM.Standard.A1.Flex** (for example 2 OCPU / 12 GB, within the free tier), and upload your SSH public key.
2. **Open the ports.** On the instance's subnet *Security List*, add Ingress rules for TCP **80** and **443** from `0.0.0.0/0`. `setup.sh` handles the VM's own iptables rules.
3. **Optional domain.** Point an A record (a free DuckDNS name works) to the VM's public IP. Without a domain, the app runs on plain HTTP at the IP. Web sign-ins then aren't remembered across reloads, because secure storage needs HTTPS.
4. **Provision once:**
   ```bash
   scp deploy/setup.sh deploy/nginx.conf.template ubuntu@<VM_IP>:~
   ssh ubuntu@<VM_IP> 'sudo SERVER_NAME=pairnest.example.com CERT_EMAIL=you@example.com bash setup.sh'
   ```
   This installs Nginx, PHP 8.3-FPM, MySQL 8, Composer and Certbot. It creates the database, generates the production `.env`, and gets an HTTPS certificate.
5. **Deploy** (from this repo, in Git Bash; rerun it for every release):
   ```bash
   SERVER=pairnest.example.com bash deploy/deploy.sh
   ```
   It builds Flutter web with the right `API_URL`, uploads a release, runs `composer install` and migrations, switches the `current` symlink and checks `/api/v1/health`.
6. **Mobile builds** point at the same API:
   ```bash
   flutter build apk --release --dart-define=API_URL=https://pairnest.example.com/api/v1
   flutter build ipa --release --dart-define=API_URL=https://pairnest.example.com/api/v1   # on a Mac
   ```

## Notes

- **Brand assets.** The official logo lives in `app/assets/brand/`:
  - `logo_full.png` is the logo with a transparent background, used on the splash and sign-in screens.
  - `logo_icon_1024.png` and `logo_icon_fg.png` are the app-icon sources.
  - After changing them, run `dart run flutter_launcher_icons` in `app/` to regenerate the Android, iOS and web icons.
- **Mascot.** In-app mascots are drawn in code to match the logo (`app/lib/core/mascot/mascot.dart`) so they follow the couple's theme. `MascotPair(animate: true)` adds the idle bob and floating heart.
- **Motion.** Shared timings and the entrance, count-up and press effects are in `app/lib/core/motion/motion.dart`. When the device's reduce-motion setting is on, all animation is skipped.
- Android builds need the Android SDK (install Android Studio, then run `flutter doctor --android-licenses`). iOS builds need a Mac with Xcode.
