# HIDE & SEEK Setup Guide

## 1) Supabase Setup

1. Create a new Supabase project.
2. Open SQL Editor and run `supabase-setup.sql`.
3. Add allowed users manually to `public.profiles`:
   - Required minimum fields: `email` and `is_active`.
   - `id` can be omitted (defaults to generated UUID).
4. Confirm realtime is active for `sessions`:
   - `supabase-setup.sql` includes `alter publication supabase_realtime add table public.sessions`.
5. Profile fields used by runtime:
   - `email` (allowlist login key)
   - `temp_code` + `temp_code_expires_at` (rotating 4-digit accomplice code)
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

1. Login:
   - Enter email.
   - App checks `profiles.email`; no match means login fails.
2. Home:
   - `PERFORM`: open waiting/result performance screen
   - `ACCOMPLICE`: generate QR + share code URL (`/accomplice/1234`)
   - `VOICE MODE`: capture spoken cards and calculate result locally
   - Activate/Deactivate toggle to control whether accomplice transmissions are accepted
3. Temp code behavior:
   - 4-digit code is generated per performer.
   - Code rotates every 60 minutes.
   - Rotation does not end an already-running performance session.
4. Perform mode:
   - Waits for accomplice submission
   - Updates via Supabase Realtime + 5s polling fallback
   - Shows signed difference and both card names

### Accomplice Flow (`accomplice.html`)

1. Opens URL `accomplice.html?s=<session-uuid>`
   - Or code URL `/accomplice/<4-digit-temp-code>`
2. Validates session:
   - Exists
   - Not expired flag
   - Not already submitted
   - Not older than 60 minutes
3. Selects SEEKER card first, then HIDER card
4. Confirms and transmits once
5. Sees success screen

## 6) Timing and Session Rules

- Session lifetime is 60 minutes from `created_at`.
- Temporary code lifetime is 60 minutes from `temp_code_expires_at`.
- Session can only be submitted once (`submitted_at` becomes non-null).
- Performer can generate new session at any time; previous active sessions are marked expired.
- Perform view shows live countdown and exits when session times out.
- If performer is deactivated, accomplice submissions are blocked.

## 7) Troubleshooting

- "Email is not authorized":
  - Ensure an active row exists in `public.profiles` for that email.
- Temp code not appearing:
  - Check `profiles_temp_code_key` unique index exists.
  - Check `temp_code_expires_at` column exists and is writable.
  - If upgrading from an older schema, run `fix-temp-code-columns.sql`.
- Accomplice shows invalid/expired:
  - Confirm URL contains `?s=<uuid>` or `/accomplice/<4-digit-code>`.
  - Confirm session still within 60 minutes and not marked expired.
  - Confirm performer is active and code has not expired.
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
