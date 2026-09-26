# odoo-dev

A local Odoo development stack in Docker. Any Odoo version, configured from a
single `.env` file, with one small CLI (`odev`) for everything you do day to
day: create databases, install and upgrade modules, run tests, back up and
restore, and pull a neutralized copy of production.

```sh
git clone https://github.com/<you>/odoo-dev.git && cd odoo-dev
./odev up            # build and start the stack
./odev init          # create a database
./odev open          # http://localhost:8069, login admin / admin
```

## Features

- **Any Odoo version** — every tag of the official [`odoo`](https://hub.docker.com/_/odoo)
  image works, including dated builds to match production exactly. Switch with
  `./odev version 18.0`.
- **One config file** — `odoo.conf` is rendered from `.env` at container start.
  Nothing hidden in three layers of config.
- **Fast dev loop** — `--dev=reload` by default, plus a `live` mode that
  re-reads templates and views on every request.
- **Safe installs and upgrades** — the server is stopped while `-i`/`-u` runs,
  so two registry loads never race each other.
- **Tests in throwaway databases** — created, run and dropped in one command.
- **Backups in Odoo's own format** — `dump.sql` + `filestore/` in a zip, so
  they restore through `odev` *and* through Odoo's database manager.
- **Production copies that don't bite** — every restore is neutralized by
  default: crons off, mail servers disarmed, webhooks dead.
- **Mail trap and DB UI on demand** — Mailpit and Adminer as optional profiles.
- **Several versions side by side** — the compose project name separates
  containers, volumes and networks.

## Requirements

- Docker with the Compose plugin (`docker compose`, v2.1 or newer)
- Bash (macOS or Linux; on Windows use WSL2)
- `curl` for `./odev status` and `./odev pull-prod`

## Quick start

```sh
./odev up                    # first run creates .env from .env.example and builds the image
./odev init                  # database "odoo" with base, without demo data
./odev init demo --demo      # a second database, with demo data
./odev install sale,stock    # install modules into the default database
./odev logs -f               # follow the logs
```

Odoo runs at <http://localhost:8069>, login `admin` / `admin`.

To work on your own modules, point `CUSTOM_ADDONS` in `.env` at your addons
repository and restart:

```sh
# .env
CUSTOM_ADDONS=../my-odoo-addons
```

```sh
./odev up
./odev install my_module
```

Or start a new module right here: `./odev scaffold my_module` creates it in
`./addons`.

## Layout

```
odoo-dev/
├── odev                   the CLI
├── compose.yml            db + odoo, plus mail and adminer as profiles
├── Dockerfile             official Odoo image + requirements.txt + psql tools
├── entrypoint.sh          renders odoo.conf, waits for Postgres
├── config/odoo.conf.tpl   template, every value comes from .env
├── .env.example           documented defaults (copied to .env on first run)
├── requirements.txt       Python dependencies of your addons
├── scripts/shot.py        screenshots of Odoo pages (Playwright)
├── addons/                scratchpad for new modules      -> /mnt/addons/local
├── oca/                   cloned OCA repositories         -> /mnt/addons/oca
└── backups/               dumps                           -> /backups
```

`addons/`, `oca/` and `backups/` are git-ignored; only their `.gitkeep` is
tracked.

### Addons path

Inside the container the addons path is

```
/mnt/addons/local, /mnt/addons/custom, /mnt/addons/oca, <Odoo core addons>
```

| Mount | Host | Purpose |
|---|---|---|
| `/mnt/addons/local` | `./addons` | quick experiments, `./odev scaffold` target |
| `/mnt/addons/custom` | `$CUSTOM_ADDONS` | your addons repository |
| `/mnt/addons/oca` | `./oca` | third-party addons, e.g. OCA |

Earlier entries win when the same module exists twice. The Odoo image adds its
core addons behind these.

**OCA repositories** contain one directory per module at the top level, but the
addons path needs the directory *containing* them. With several OCA repos,
clone them into a subfolder and symlink the modules you need into `oca/`
(relative links resolve inside the container too), or add the repo
directories to the path yourself (see [Customizing](#customizing)):

```sh
git clone --depth 1 -b 18.0 https://github.com/OCA/web.git oca/src/web
cd oca && ln -s src/web/web_responsive . && cd ..
./odev install web_responsive
```

**Python dependencies** of your addons go into `requirements.txt`, then
`./odev build` (or `./odev up --build`).

## How configuration works

`config/odoo.conf.tpl` contains placeholders such as `${WORKERS}`. On startup,
`entrypoint.sh` renders it with the container environment to `/tmp/odoo.conf`
and `ODOO_RC` points there. Two consequences:

- Everything configurable lives in **one** file: `.env`.
- `docker compose exec odoo odoo <command>` finds its configuration by itself —
  no `-c`, no `--db_*` arguments.

After changing `.env`, run `./odev up` — Compose recreates the containers whose
configuration changed.

### Settings

All variables in `.env`, with their defaults:

| Variable | Default | Meaning |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `odoo19` | Separates containers, volumes and networks of parallel stacks |
| `ODOO_VERSION` | `19.0` | Tag of the official `odoo` image |
| `POSTGRES_VERSION` | `17-alpine` | Tag of the `postgres` image |
| `ODOO_PORT` | `8069` | Odoo HTTP on the host |
| `ODOO_GEVENT_PORT` | `8072` | Longpolling / websocket port on the host |
| `DB_HOST_PORT` | `5435` | Postgres on the host (for external clients only) |
| `MAILPIT_UI_PORT` / `MAILPIT_SMTP_PORT` | `8026` / `1026` | Mailpit on the host |
| `ADMINER_PORT` | `8081` | Adminer on the host |
| `DB_USER` / `DB_PASSWORD` | `odoo` / `odoo` | Postgres credentials |
| `DB_MAXCONN` | `64` | `db_maxconn` |
| `DB_FILTER` | `.*` | `dbfilter` |
| `LIST_DB` | `True` | Show the database manager and selector |
| `ODOO_DB` | `odoo` | Default database for every `odev` command with an optional `[db]` |
| `ADMIN_PASSWD` | `admin` | Master password of the database manager |
| `CUSTOM_ADDONS` | `./addons` | Your addons repository, relative to this folder |
| `WORKERS` | `0` | `workers`; must be `0` for reload and debuggers |
| `MAX_CRON_THREADS` | `2` | `max_cron_threads` |
| `LIMIT_TIME_CPU` / `LIMIT_TIME_REAL` | `600` / `1200` | Request time limits in seconds |
| `LIMIT_MEMORY_SOFT` / `LIMIT_MEMORY_HARD` | 2 GiB / 2.5 GiB | Worker memory limits in bytes |
| `PROXY_MODE` | `False` | `proxy_mode` |
| `LOG_LEVEL` / `LOG_HANDLER` | `info` / `:INFO` | Logging |
| `ODOO_EXTRA_ARGS` | `--dev=reload` | Extra arguments for `odoo`; set by `./odev mode` |
| `SMTP_SERVER` / `SMTP_PORT` | `mail` / `1025` | Outgoing mail, points at Mailpit |
| `EMAIL_FROM` | `odoo@localhost` | Default sender |
| `PROD_URL` / `PROD_DB` / `PROD_MASTER_PW` | empty | Source for `./odev pull-prod` |

## Commands

Every command that takes an optional `[db]` falls back to `ODOO_DB`. Modules
are given comma-separated: `sale,stock`.

### Stack

| Command | |
|---|---|
| `./odev up [--mail] [--tools] [--build]` | Start the stack. `--mail` adds Mailpit, `--tools` Adminer, `--build` rebuilds first |
| `./odev down [-v]` | Stop everything; `-v` also deletes the volumes (databases and filestore!) |
| `./odev restart [service]` | Restart a service (default `odoo`) |
| `./odev build [--no-cache]` | Rebuild the image |
| `./odev ps` | Container status |
| `./odev logs [-f] [service]` | Logs (default: last 100 lines) |
| `./odev status` | Containers, health endpoint, databases and addons at a glance |
| `./odev version [tag]` | Show the Odoo version, or switch to another tag and rebuild |
| `./odev mode [fast\|live]` | Show or switch the dev mode, see [Developing](#developing) |

### Database

| Command | |
|---|---|
| `./odev init [db] [--demo]` | Create a database with `base`; without demo data unless `--demo` |
| `./odev drop [db]` | Delete a database and its filestore (asks first) |
| `./odev reset` | Delete containers and volumes, then create a fresh default database (asks first) |
| `./odev psql [db]` | Interactive psql |
| `./odev duplicate <source> <target>` | Copy a database including its filestore |

### Modules

| Command | |
|---|---|
| `./odev install <mods> [db]` | Install modules |
| `./odev upgrade <mods> [db]` | Upgrade modules |
| `./odev update-all [db]` | Upgrade all installed modules |
| `./odev uninstall <mods> [db]` | Uninstall modules |
| `./odev test <mods>` | Install the modules into a throwaway database, run their tests, drop it |
| `./odev scaffold <name>` | New module skeleton in `./addons` |

`install`, `upgrade` and `update-all` stop the running server, run Odoo once
with `--stop-after-init`, and start the server again. Running both at the same
time makes the two registry loads collide ("could not serialize access due to
concurrent update") and can leave a database half-migrated.

### Data

| Command | |
|---|---|
| `./odev backup [db]` | Dump **including filestore** to `./backups/<db>-<timestamp>.zip` |
| `./odev restore <file> [db] [--no-neutralize]` | Restore a zip dump, neutralized unless `--no-neutralize` |
| `./odev pull-prod [db]` | Download a dump from production and restore it (neutralized) |
| `./odev neutralize [db]` | Neutralize an existing database |

### Misc

| Command | |
|---|---|
| `./odev shell [db]` | Odoo shell, with `env` ready |
| `./odev bash` | Bash in the odoo container |
| `./odev open` | Open Odoo in the browser |
| `./odev help` | List all commands |

`odev` is a thin layer over `docker compose` — everything it does you can also
do by hand, e.g. `docker compose exec odoo odoo shell -d odoo`.

## Developing

Two modes, switched with `./odev mode fast|live` (without argument: show the
current mode):

| Mode | `ODOO_EXTRA_ARGS` | Page load | After changes |
|---|---|---|---|
| **fast** (default) | `--dev=reload` | milliseconds | Python: automatic · SCSS/JS: `./odev restart` · XML: `./odev upgrade <module>` |
| **live** | `--dev=reload,qweb,xml` | 2–6 seconds | Python, XML, SCSS/JS: automatic |

`xml` disables Odoo's template, view and asset caches at once — every page is
compiled again on every request. Measured on this stack: home page 3.8 s →
0.01 s, `/shop` 5.8 s → 0.15 s when switching from live to fast. So only turn
on `live` while you are actually working on templates.

Reload only works with `WORKERS=0`; with workers, neither reload nor a
debugger works. For load tests set `WORKERS` to `(2 × CPU) + 1` and clear
`ODOO_EXTRA_ARGS`.

Structural changes — new fields, new models, changed access rules, new data
files — always need `./odev upgrade <module>`.

### Tests

```sh
./odev test my_module
./odev test my_module,my_other_module
```

Each run gets a fresh database `test_<time>` that is dropped afterwards, so
tests never touch your working data. Tests are selected with
`--test-tags /my_module`.

### Screenshots

`scripts/shot.py` takes a screenshot of a page from a given database and
prints JavaScript console errors and SCSS compile errors — handy for checking
frontend changes or for scripted before/after comparisons.

```sh
pip install playwright && playwright install chromium
python3 scripts/shot.py odoo /shop shop.png --full
python3 scripts/shot.py odoo /odoo backend.png --login admin:admin
python3 scripts/shot.py odoo /my portal.png --mobile --login portal:portal
```

The base URL is `$ODOO_URL`, or `http://localhost:$ODOO_PORT`.

### Mail

`./odev up --mail` starts [Mailpit](https://mailpit.axllent.org/). Odoo sends
through it by default (`SMTP_SERVER=mail`); every mail lands in the web UI at
<http://localhost:8026> instead of a real inbox. Without the profile, mail
simply fails to send — which is what you want in a dev copy.

Note that a database's own *outgoing mail servers* (Settings → Technical)
override `smtp_server`. Neutralizing a database disables them.

## Backups and production copies

### Backup and restore

```sh
./odev backup                            # backups/odoo-20260926-120000.zip
./odev restore backups/odoo-...zip       # into the default database
./odev restore dump.zip staging          # into another database
```

The archive format is Odoo's own: `dump.sql` plus `filestore/`. Backups from
`odev` can be restored through Odoo's database manager and vice versa — a dump
downloaded from `/web/database/manager` goes straight into `./odev restore`.

### Neutralizing

A copy of production sends real mails to real customers the first time a
cron runs. So `restore` and `pull-prod` run `odoo neutralize` afterwards:
crons off, mail servers disarmed, webhooks and payment providers disabled
(exactly what depends on the installed modules — each module contributes its
own neutralization). Needs Odoo 16 or newer. If you really want a live copy,
add `--no-neutralize`.

### Pulling from production

Set in `.env`:

```sh
PROD_URL=https://erp.example.com
PROD_DB=production_db_name
PROD_MASTER_PW=...          # master password of the production instance
```

then

```sh
./odev pull-prod
```

This downloads a zip dump through the production database manager
(`/web/database/backup`), stores it in `./backups/prod-<timestamp>.zip`,
restores database and filestore, and neutralizes. It works with any Odoo
instance whose database manager is reachable. If yours isn't (Odoo.sh, managed
hosting), download the dump from your hosting panel and use `./odev restore`.

The production database must be restored into a stack with the **same** Odoo
version.

## Multiple versions side by side

Copy the folder, and in the copy's `.env` change the project name, the version
and the ports:

```sh
COMPOSE_PROJECT_NAME=odoo18
ODOO_VERSION=18.0
ODOO_PORT=8068
ODOO_GEVENT_PORT=8071
DB_HOST_PORT=5436
```

The project name separates containers, volumes and networks, so the two stacks
never interfere.

A database always belongs to the version it was created with. Switching the
version within one project (`./odev version 18.0`) needs either an upgrade or
a fresh start with `./odev reset`.

## Ports

| Service | Host port | `.env` |
|---|---|---|
| Odoo | 8069 | `ODOO_PORT` |
| Odoo longpolling / websocket | 8072 | `ODOO_GEVENT_PORT` |
| Postgres | 5435 | `DB_HOST_PORT` |
| Mailpit UI / SMTP | 8026 / 1026 | `MAILPIT_UI_PORT` / `MAILPIT_SMTP_PORT` |
| Adminer | 8081 | `ADMINER_PORT` |

Postgres is published only for external database clients (e.g.
`psql -h localhost -p 5435 -U odoo`) — Odoo itself talks to `db:5432` on the
internal network. On a port clash, change the value in `.env`.

## Customizing

- **More Odoo options**: add a line to `config/odoo.conf.tpl`, e.g.
  `server_wide_modules = ${SERVER_WIDE_MODULES}`, the variable to `.env`, and
  pass it through in the `environment:` block of the `odoo` service in
  `compose.yml`.
- **Additional addons directories**: mount them in `compose.yml` and extend
  `ADDONS_PATH` there.
- **System packages**: add them to the `apt-get install` line in the
  `Dockerfile`, then `./odev build`.

## Why no logfile

Odoo logs to stdout so that `docker compose logs` works and the host's log
driver applies. A `logfile =` in the configuration would bypass both and fill
a file inside the container that nobody rotates.

## Troubleshooting

**Port already in use** — change the port in `.env`, then `./odev up`.

**`database 'odoo' does not exist`** — run `./odev init` first.

**Module not found** — check `./odev status` for the mounted addons. The path
in `CUSTOM_ADDONS` must be the directory *containing* your modules. After
adding a new module, update the apps list or just `./odev install <module>`.

**Changes don't show up** — Python reloads automatically; XML needs
`./odev upgrade <module>` (or `./odev mode live`); SCSS/JS needs
`./odev restart` in fast mode. Hard-refresh the browser afterwards.

**`could not serialize access due to concurrent update`** — two Odoo
processes loaded the registry at the same time. Use `./odev install` /
`./odev upgrade` rather than running `odoo -u` next to the server.

**Permission denied in `backups/` or `addons/` (Linux)** — the container runs
as user `odoo` (uid 101), which can't write to directories owned by your user.
Make them writable, e.g. `chmod o+w backups addons`. Docker Desktop on macOS
and Windows maps permissions and doesn't need this.

**Starting over** — `./odev reset` deletes containers and volumes and creates
a fresh default database.

## Security

This is a development stack: `admin_passwd=admin`, `list_db=True`, a weak
database password, Postgres published on the host. None of that belongs on a
host reachable from the internet. For anything beyond local development set at
least `LIST_DB=False`, a real `ADMIN_PASSWD`, a strict `DB_FILTER`, a real
`DB_PASSWORD`, and `PROXY_MODE=True` behind a reverse proxy.

`.env` is git-ignored because it may contain `PROD_MASTER_PW`. Keep it that
way, and keep production dumps out of shared places: they contain customer
data.

## Contributing

Issues and pull requests are welcome. CI runs `shellcheck` on `odev` and
`entrypoint.sh` and a smoke test (build, init, backup, restore); please keep
both green.

## License

[MIT](LICENSE)
