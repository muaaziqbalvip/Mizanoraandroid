# MizanoraAndroid

A personal, always-on Android emulator that lives on GitHub Actions.

```
GitHub Actions (emulator + ws-scrcpy + cloudflared)  ──publishes URL──▶  `status` branch
        ▲  re-dispatches itself every ~5h30                                   │
        │                                                                     ▼
 watchdog.yml (every 15 min)                         Vercel panel (web/)  ◀── Android app (APK)
```

## Setup
1. Create a **public** GitHub repo `MizanoraAndroid`, push this folder.
2. Edit `window.MIZANORA_REPO` in `web/index.html` → `yourname/MizanoraAndroid`.
3. Vercel → Import repo → **Root Directory: `web`** → Deploy. Note the URL.
4. Repo → Settings → Secrets and variables → Actions → **Variables** → add `PANEL_URL` = your Vercel URL.
5. Actions tab → run **Emulator (24/7 loop)** once. Watchdog keeps it alive after that.
6. Actions tab → run **Build & Release APK** → download `MizanoraAndroid.apk` from Releases.

## Known limits
- Tunnel URL is public (random) – anyone with it can control the phone. Add Cloudflare Access / auth before real use.
- Emulator data resets every restart. 1–3 min gaps are possible if handover fails.
- Scheduled workflows pause after 60 days of repo inactivity.
- 24/7 use of Actions may breach GitHub's terms. Use a throwaway account.
