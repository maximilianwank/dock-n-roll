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

### :robot: Automate Creation of Backup

You can make cron run the backup script, for example by adding the line

```text
0 4 * * * cd /path/to/dock-n-roll && ./backup_create.sh
```

to your crontab.

### :previous_track_button: Backup Restore

If necessary, stop the containers

```bash
docker compose down
```

Unzip the archive via

```bash
unzip -P your_password_here docker_volumes_backup_{weekday}.zip -d zip_restore
```

Copy the docker_volumes folder

```bash
cp -r zip_restore/home/maxi/docker_volumes docker_volumes
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
