# syntax=docker/dockerfile:1
ARG ODOO_VERSION=19.0
FROM odoo:${ODOO_VERSION}

USER root

# Tools for backup/restore and debugging inside the container
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-client \
        less \
        vim-tiny; \
    rm -rf /var/lib/apt/lists/*

# Python dependencies of your own addons.
# Cached as its own layer: changing requirements.txt only re-runs this step.
COPY requirements.txt /tmp/requirements.txt
RUN set -eux; \
    if grep -qvE '^\s*(#|$)' /tmp/requirements.txt; then \
        pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt; \
    fi; \
    rm -f /tmp/requirements.txt

# Own entrypoint: renders odoo.conf from the template and waits for Postgres
COPY entrypoint.sh /usr/local/bin/odoo-dev-entrypoint.sh
RUN chmod +x /usr/local/bin/odoo-dev-entrypoint.sh

RUN set -eux; \
    mkdir -p /mnt/addons/local /mnt/addons/custom /mnt/addons/oca /backups; \
    chown -R odoo:odoo /mnt/addons /backups

# odoo reads this file automatically -> "docker compose exec odoo odoo db dump ..."
# works without -c and without any database arguments
ENV ODOO_RC=/tmp/odoo.conf

USER odoo

ENTRYPOINT ["/usr/local/bin/odoo-dev-entrypoint.sh"]
CMD ["odoo"]
