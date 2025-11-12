# :whale2: dock-n-roll

Setup for my "[homelab](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)" with docker containers.

This project is still under development and therefore not very stable or well documented.

## :construction_worker_man: Setup

1. Clone the repository
2. Copy `.env.template` to `.env`
3. Modify `.env` respecitvely
4. Copy `Caddyfile` to the docker volumes
5. Run `docker-compose up -d`

## :information_source: Tips & Tricks

### :floppy_disk: Backup & Restore

#### Creating Backups

The backup script creates encrypted, compressed archives of your Docker volumes:

```bash
./backup_create.sh
```

**What it does:**
- Stops all containers
- Creates a `tar.gz` archive of your Docker volumes (excludes metube downloads)
- Restarts containers to minimize downtime
- Encrypts the archive with GPG using `BACKUP_PASSWORD` from `.env`
- Saves as `{weekday}.tar.gz.gpg` in your `BACKUP_DIR`

**Automate with cron:**

Add this line to your crontab to run backups daily at 4 AM:

```text
0 4 * * * cd /path/to/dock-n-roll && ./backup_create.sh
```

#### Restoring Backups

The restore script decrypts and extracts backup archives:

```bash
./backup_restore.sh /path/to/monday.tar.gz.gpg
```

**What it does:**
- Prompts for the restore destination path
- Asks for confirmation before overwriting existing data
- Decrypts the GPG-encrypted backup (prompts for password)
- Extracts the archive to the specified location

**Manual restore steps:**

1. Stop containers (if needed):
   ```bash
   docker compose down
   ```

2. Run the restore script:
   ```bash
   ./backup_restore.sh monday.tar.gz.gpg
   ```

3. Follow the prompts to enter destination path and password

4. Start containers again:
   ```bash
   docker compose up -d
   ```

### :truck: Caddy

Reload the config file via

```bash
docker exec -it caddy caddy reload -c /etc/caddy/Caddyfile
```

### :hole: Pi-hole

Set the admin password via running

```bash
docker exec -it pihole pihole -a -p
```

on the host.

### :books: Odoo

To generate pdfs, it might be necessary to set the system parameter `report.url` to `http://0.0.0.0:8069`, see [here](https://github.com/odoo/docker/issues/238#issuecomment-457216876).
