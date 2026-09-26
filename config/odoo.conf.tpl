# Template — rendered with environment variables when the container starts.
# Everything configurable comes from .env; nothing is hard-wired here.
[options]

# --- Addons -----------------------------------------------------------------
# local  = ./addons        (scratchpad for new modules)
# custom = $CUSTOM_ADDONS  (your addons repository)
# oca    = ./oca           (cloned OCA repositories)
addons_path = ${ADDONS_PATH}
data_dir = /var/lib/odoo

# --- Database ---------------------------------------------------------------
db_host = ${DB_HOST}
db_port = ${DB_PORT}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
db_maxconn = ${DB_MAXCONN}
dbfilter = ${DB_FILTER}
list_db = ${LIST_DB}
admin_passwd = ${ADMIN_PASSWD}

# --- HTTP -------------------------------------------------------------------
http_enable = True
http_interface = 0.0.0.0
http_port = 8069
gevent_port = 8072
proxy_mode = ${PROXY_MODE}

# --- Processes --------------------------------------------------------------
# workers = 0 -> single process, required for --dev=reload and debuggers.
# For load tests raise to (2 x CPU) + 1.
workers = ${WORKERS}
max_cron_threads = ${MAX_CRON_THREADS}
limit_time_cpu = ${LIMIT_TIME_CPU}
limit_time_real = ${LIMIT_TIME_REAL}
limit_memory_soft = ${LIMIT_MEMORY_SOFT}
limit_memory_hard = ${LIMIT_MEMORY_HARD}

# --- Logging ----------------------------------------------------------------
# No logfile: everything goes to stdout so "docker compose logs" works.
log_level = ${LOG_LEVEL}
log_handler = ${LOG_HANDLER}

# --- Mail -------------------------------------------------------------------
smtp_server = ${SMTP_SERVER}
smtp_port = ${SMTP_PORT}
email_from = ${EMAIL_FROM}
