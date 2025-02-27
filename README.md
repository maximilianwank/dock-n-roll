# :whale2: dock-n-roll

Setup for my ["homelab"](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/) with docker containers.

## :information_source: Tips & Tricks

### :previous_track_button: Backup restore

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

### :hole: Pi-hole

Set the admin password via running

```bash
docker exec -it pihole pihole -a -p
```

on the host.
