# TradeWars: Galactic Frontier

A persistent, multiplayer space trading and combat game inspired by the
classic BBS door game *Trade Wars 2002*, deployed at
**https://tradewars.paigejulianne.com**.

Player-facing documentation (how to play) lives inside the app itself
(Manual tab) and as source markdown in `frontend/assets/docs/`. This file is
operational documentation for whoever maintains the server.

## Architecture

```
Flutter web app (PWA)  --HTTPS-->  Apache  --Alias /api-->  PHP 8.5 REST API  --> MariaDB
                        --wss:///ws-->      --ProxyPass /ws--> Go WebSocket server --^
```

- **frontend/** — Flutter web app (Dart). Builds to `frontend/build/web`,
  served directly by Apache as static files (index.html SPA fallback via
  mod_rewrite). Installable as a PWA; the app shell and bundled manual work
  offline, gameplay requires the backend.
- **backend/** — PHP 8.5, no framework. `backend/public/api/*.php` are
  individually-routed REST endpoints (no front controller). `backend/src/`
  has the autoloaded `TradeWars\Core` (DB, Auth, Mailer, Request, Response)
  and `TradeWars\Game` (Economy, Combat, Galaxy, TurnManager, Events,
  PlayerOps) classes. `backend/config/config.php` holds DB credentials and
  app secrets (not readable by anyone but www-data — mode 640).
- **wsserver/** — Go real-time server. Authenticates WebSocket connections
  against the same `sessions` table PHP writes, tracks per-sector presence,
  tails `events_log`/`chat_messages` for new rows and fans them out, and
  runs the ambient random-events engine (raider/monster spawns, cosmic
  storms, mine fields). Built as a static binary, run under systemd.
- **db/schema.sql** — full schema. **db/seed_ship_types.sql** — ship class
  data. **backend/scripts/generate_galaxy.php** — galaxy generator /
  reseed script (sectors, warps, ports, planets, starting NPCs).

## Redeploying after a code change

**Backend (PHP):** edit files under `backend/`, no build step. Just make
sure `chown -R www-data:www-data backend` if new files were added as root.

**WebSocket server (Go):**
```
cd /srv/tradewars.paigejulianne.com/wsserver
go build -o tradewars-wsserver .
chown www-data:www-data tradewars-wsserver
systemctl restart tradewars-wsserver
```

**Frontend (Flutter):**
```
cd /srv/tradewars.paigejulianne.com/frontend
/opt/flutter/bin/flutter build web --release --pwa-strategy=offline-first
chown -R www-data:www-data build
```
Note: the PWA service worker aggressively caches — a hard reload
(Ctrl+Shift+R) is needed to see a new deploy in a browser that already has
it installed/cached.

## Services

| Service | Manage with |
|---|---|
| Apache (frontend + PHP API) | `systemctl reload apache2` after config changes |
| Go WebSocket server | `systemctl {status,restart} tradewars-wsserver` |
| MariaDB | `systemctl status mariadb` |

Apache vhost config: `/etc/apache2/sites-available/tradewars.paigejulianne.com{,-le-ssl}.conf`.
WS server unit: `/etc/systemd/system/tradewars-wsserver.service`, env file
at `wsserver/wsserver.env` (DB DSN — not committed to any repo, mode 640).

## Database

- Database `tradewars`, user `tradewars`@`localhost`. Credentials in
  `db/.dbcreds` (mode 600) and `backend/config/config.php` (mode 640).
- Reseed/regenerate the galaxy: `php backend/scripts/generate_galaxy.php 600 --wipe`
  (danger: wipes sectors/warps/ports/planets/NPCs, **not** players/users).

## Email

Verification and password-reset emails are sent via PHP's `mail()` through
the server's local Postfix, which relays outbound through smtp2go — no
additional SMTP configuration needed on this host.

## Known simplifications / roadmap

This is a solid, fully playable first release, not a 1:1 TW2002 clone.
Deliberately out of scope for now (see in-app docs for what's live):
planet citadel upgrades and defense-fighter purchases, ship cloaking having
an actual gameplay effect, colonist population growth over time,
corporation treasuries being spendable, and leaving a corporation. The
architecture (dedicated `Game` classes, `events_log`-driven real-time
fan-out) is built to make adding these straightforward.
