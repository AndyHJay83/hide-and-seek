# HIDE & SEEK Setup Guide

## 1) Supabase Setup

1. Create a new Supabase project.
2. Open SQL Editor and run `supabase-setup.sql`.
3. Add your purchase codes:
   - Either run manual inserts in SQL, or use the commented seed block in `supabase-setup.sql`.
   - Store and compare all codes in uppercase format (for example `HAS-ABCD-0001`).
4. In Supabase Authentication:
   - Enable Anonymous sign-in (used for persistent app identity).
   - Email OTP is no longer required by default app flow.
5. Configure SMTP for reliable delivery:
   - Recommended: Resend free tier SMTP.
   - In Supabase Auth > SMTP Settings, add your Resend SMTP host/user/pass and sender email.
6. Confirm realtime is active for `sessions`:
   - `supabase-setup.sql` includes `alter publication supabase_realtime add table public.sessions`.
7. New profile fields:
   - `public_code` (unique single-digit code `0-9`)
   - `pin_hash` and `pin_salt` (PIN unlock data)
   - `is_active` (performer can activate/deactivate live receiving)

## 2) GitHub Pages Setup

1. Create a GitHub repository.
2. Upload all project files from this folder.
3. In GitHub repo settings, enable Pages:
   - Source: Deploy from a branch.
   - Branch: `main` (root).
4. Wait for Pages deployment URL to appear.

## 3) Configure `config.js`

Edit `config.js`:

```js
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_PUBLIC_KEY_HERE';
const APP_URL = 'https://YOUR_GITHUB_USERNAME.github.io/YOUR_REPO_NAME';
```

- `SUPABASE_URL`: from Supabase project API settings
- `SUPABASE_ANON_KEY`: from Supabase API settings (`anon public`)
- `APP_URL`: your exact GitHub Pages base URL (no trailing slash)

## 4) Add PWA Icons

Place two PNG files at repo root:

- `icon-192.png` (192x192)
- `icon-512.png` (512x512)

These are referenced by `manifest.json`.

## 4.1) Camera AI Proxy (Vercel)

The custom stack camera flow can call Claude Vision through a serverless proxy:

- Endpoint path: `/api/claude-cards`
- File in repo: `api/claude-cards.js`
- Required env var in Vercel project settings:
  - `ANTHROPIC_API_KEY` = your Anthropic API key

Notes:
- This keeps your API key off the client.
- The app defaults to same-origin `/api/claude-cards` if `ANTHROPIC_PROXY_URL` is not set in `config.js`.
- If hosting on GitHub Pages only (no serverless functions), this endpoint will not exist.

## 5) How the App Works

### Performer Flow (`index.html`)

1. Register:
   - Enter purchase code
   - Enter email
   - Choose permanent public code (example: `7`)
   - Set 6-digit PIN
   - App creates profile then redeems code
2. Login:
   - Enter 6-digit PIN only on the same device
3. Home:
   - `PERFORM`: open waiting/result performance screen
   - `ACCOMPLICE`: generate QR + share reusable code URL (`/accomplice/PUBLICCODE`)
   - `VOICE MODE`: capture spoken cards and calculate result locally
   - Activate/Deactivate toggle to control whether accomplice transmissions are accepted
4. Perform mode:
   - Waits for accomplice submission
   - Updates via Supabase Realtime + 5s polling fallback
   - Shows signed difference and both card names

### Accomplice Flow (`accomplice.html`)

1. Opens URL `accomplice.html?s=<session-uuid>`
   - Or reusable URL `/accomplice/<PUBLICCODE>`
2. Validates session:
   - Exists
   - Not expired flag
   - Not already submitted
   - Not older than 30 minutes
3. Selects SEEKER card first, then HIDER card
4. Confirms and transmits once
5. Sees success screen

## 6) Timing and Session Rules

- Session lifetime is 30 minutes from `created_at`.
- Session can only be submitted once (`submitted_at` becomes non-null).
- Performer can generate new session at any time; previous active sessions are marked expired.
- Perform view shows live countdown and exits when session times out.
- If performer is deactivated, accomplice submissions are blocked.

## 7) Troubleshooting

- OTP not arriving:
  - Check Supabase auth email settings.
  - Verify SMTP credentials and sender domain in Resend.
  - Check spam/junk folder.
- "No profile found" on login:
  - User has not completed registration profile creation.
- Accomplice shows invalid/expired:
  - Confirm URL contains `?s=<uuid>` or `?c=<PUBLICCODE>`.
  - Confirm session still within 30 minutes and not marked expired.
- Public code conflict on registration:
  - Code must be exactly 1 digit (`0-9`).
  - Code must be unique across all users.
- Voice mode not working:
  - Use Chrome-based browsers for best `SpeechRecognition` support.
  - Allow microphone permissions.
  - Speak clearly and include both cards; labels like "seeker" / "hider" improve accuracy.
- Realtime feels delayed:
  - Polling fallback runs every 5 seconds.
  - Verify `sessions` table is in `supabase_realtime` publication.
- Clipboard copy issues:
  - GitHub Pages is HTTPS; clipboard should work.
  - Prompt fallback appears when clipboard is unavailable.

## 8) Adding Phrase Output Later

Current `showPerformResult` calculates and displays signed difference.

Example phrase mapping:

```js
const PHRASES = {
  '-3': 'Three behind',
  '-2': 'Two behind',
  '-1': 'One behind',
  '0': 'Exact match',
  '1': 'One ahead',
  '2': 'Two ahead',
  '3': 'Three ahead'
};

function showPerformResult(data) {
  const diff = calcDiff(data.seeker_suit, data.seeker_value, data.hider_suit, data.hider_value);
  const signed = diff > 0 ? '+' + diff : String(diff);
  const phrase = PHRASES[String(diff)] || signed;
  const main = el('perform-main');
  main.innerHTML =
    '<div class="perform-num">' + phrase + '</div>' +
    '<div class="perform-sub">' + cardLabel(data.seeker_suit, data.seeker_value) + '</div>' +
    '<div class="perform-sub">' + cardLabel(data.hider_suit, data.hider_value) + '</div>';
}
```
