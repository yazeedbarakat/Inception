# Developer Documentation

This document explains how to set up, build, run and maintain the Inception stack from scratch.

## 1. Set up the environment from scratch

### Prerequisites

- A Linux virtual machine (this project was developed on Debian 12)
- Docker Engine and the Docker Compose plugin (`docker compose version` must work)
- `make`
- Your user must be able to run Docker (member of the `docker` group, or use `sudo`)

### Domain name

Add the domain to `/etc/hosts` so that it points to the machine's IP address:

```
127.0.0.1   ybarakat.42.fr
```

### Repository layout

```
.
├── Makefile
└── srcs/
    ├── docker-compose.yml
    ├── .env                          # local only, never committed
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/entrypoint.sh
        └── nginx/
            ├── Dockerfile
            └── conf/nginx.conf
```

### Configuration file: `srcs/.env`

The `.env` file is read by Docker Compose and passed to the containers. Create it with these variables (use your own values):

```
DOMAIN_NAME=ybarakat.42.fr

DB_NAME=inception
DB_HOST=mariadb
DB_ROOT_PASS=<root password>
DB_USER=<mariadb user used by wordpress>
DB_USER_PASS=<password>

WP_TITLE=inception
WP_ADMIN_USER=<wordpress admin, must not contain "admin">
WP_ADMIN_PASS=<password>
WP_ADMIN_EMAIL=<email>
WP_USER=<second wordpress user>
WP_USER_PASS=<password>
WP_USER_EMAIL=<email, different from the admin's>

DATA_PATH=/home/<login>/data
```

`DATA_PATH` is used by `docker-compose.yml` to place the volumes on the host. The entrypoint scripts read the other variables at first start to create the database, the MariaDB user and the two WordPress accounts.

**`srcs/.env` contains passwords: it must never be committed to git, and no credential may be written in a Dockerfile.**

## 2. Build and launch with the Makefile and Docker Compose

The `Makefile` is at the root and drives `srcs/docker-compose.yml`.

| Command       | What it runs                                                                  |
|---------------|-------------------------------------------------------------------------------|
| `make`        | Creates the host data folders, then `docker compose -f srcs/docker-compose.yml up -d --build` |
| `make down`   | `docker compose -f srcs/docker-compose.yml down` (keeps volumes and data)     |
| `make clean`  | `down --rmi all -v` (removes containers, images and volumes)                  |
| `make fclean` | `clean`, then deletes the data in `/home/<login>/data/`                       |
| `make re`     | `fclean` then `all`                                                           |

What happens on `make`:

1. `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress` are created (they must exist before the volumes can be mounted).
2. Compose builds one image per service from its own Dockerfile (all based on `debian:12`) and tags it `<service>:inception`.
3. Containers start on the `inception` network: `mariadb`, then `wordpress`, then `nginx`.
4. Each entrypoint script performs its first-run setup, then `exec`s the real service in the foreground as PID 1.

## 3. Manage the containers and volumes

All commands below assume you run them from the repository root.

**Containers**

```
docker compose -f srcs/docker-compose.yml ps              # status
docker compose -f srcs/docker-compose.yml logs -f         # follow all logs
docker compose -f srcs/docker-compose.yml logs wordpress  # one service
docker compose -f srcs/docker-compose.yml restart nginx   # restart one service
docker compose -f srcs/docker-compose.yml build --no-cache wordpress   # rebuild one image
```

**Get a shell or run a command in a running container**

```
docker exec -it wordpress bash
docker exec -it mariadb mariadb -u root -p                 # as root
docker exec -it mariadb mariadb -u <DB_USER> -p inception  # as the WordPress database user
```

Root has a password and cannot log in without it. The WordPress database user is created for host `%`, so it can also connect from the wordpress container: `mariadb -h mariadb -u <DB_USER> -p`.

**Volumes and network**

```
docker volume ls
docker volume inspect srcs_mariadb_vol
docker network ls
docker network inspect srcs_inception
```

**Rebuild after changing a script or Dockerfile**

Containers do not update by themselves when an image changes. Rebuild and recreate:

```
make down
make
```

If you changed first-run logic (an entrypoint's init block), the data directories must be empty for it to run again: use `make re`.

## 4. Where the data is stored and how it persists

There are two named volumes, declared in `docker-compose.yml`:

| Volume          | Mounted in the container          | Stored on the host                  | Contains                  |
|-----------------|-----------------------------------|-------------------------------------|---------------------------|
| `mariadb_vol`   | `/var/lib/mysql` (mariadb)        | `/home/<login>/data/mariadb`        | The WordPress database    |
| `wordpress_vol` | `/var/www/html` (wordpress, nginx)| `/home/<login>/data/wordpress`      | WordPress files and uploads |

They are Docker **named volumes** (not bind mounts in the service definitions); their `driver_opts` point Docker to the folders above (`${DATA_PATH}` from `srcs/.env`) so the data is easy to find on the host. Check it with `docker volume inspect srcs_mariadb_vol`: the path appears under `Options.device`.

Persistence behaviour:

- `make down` / container restart / crash: data is kept.
- `make clean`: Docker removes the volumes, but the folders under `/home/<login>/data/` still contain the data, which is picked up again on the next `make`.
- `make fclean` / `make re`: the host folders are emptied, so the next start is a completely fresh install.

The entrypoint scripts detect existing data (`/var/lib/mysql/mysql` for MariaDB, `wp-config.php` for WordPress), so they only initialise the database and install WordPress the very first time.

## 5. Notes for debugging

- **nginx exits with `host not found in upstream "wordpress"`**: nginx was started outside the Compose network. Always start the stack through Compose so all containers share the `inception` network.
- **MariaDB users do not exist / the init block was skipped**: the Dockerfile must delete the data directory the Debian package creates at install time (`rm -rf /var/lib/mysql/*`), and the volume folder on the host must be empty.
- **Environment variables are empty in a container**: check `docker exec <container> env` and that `env_file` points to `srcs/.env`.
- **WordPress files owned by root**: run `chown -R www-data:www-data /var/www/html` after WP-CLI has written the files (this is done in the wordpress entrypoint).
- **TLS**: nginx is configured to accept only modern TLS (see `ssl_protocols` in `srcs/requirements/nginx/conf/nginx.conf`). Check with `openssl s_client -connect ybarakat.42.fr:443 -tls1_3`.
- **Submission path**: the subject requires the data under `/home/<login>/data`. Make sure `DATA_PATH` in `srcs/.env` and the folders created by the Makefile use your actual login before evaluation.
