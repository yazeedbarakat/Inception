*This activity has been created as part of the 42 curriculum by ybarakat*

# Inception

## Description

Inception is a system administration project built around Docker. The goal is to set up a small web infrastructure inside a virtual machine, where every service runs in its own container, and every image is built by hand from a bare Debian base (no ready-made images from Docker Hub).

The stack is made of three services:

| Service     | Role                                                        |
|-------------|-------------------------------------------------------------|
| `nginx`     | The only entrypoint. Serves HTTPS on port 443 (TLS only).   |
| `wordpress` | WordPress running on php-fpm (port 9000), no web server in it. |
| `mariadb`   | The database WordPress stores its content in.               |

Request flow: `browser -> nginx:443 -> wordpress:9000 (php-fpm) -> mariadb:3306`

Two named volumes persist the data (the database and the WordPress files), and a custom Docker network connects the containers.

### Project sources

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── .env                    # configuration and passwords, local only
    └── requirements/
        ├── mariadb/   (Dockerfile, tools/entrypoint.sh)
        ├── nginx/     (Dockerfile, conf/nginx.conf)
        └── wordpress/ (Dockerfile, tools/entrypoint.sh)
```

- Each service has its own `Dockerfile`, built from `debian:12` (the penultimate stable Debian release).
- `entrypoint.sh` scripts run at container start, configure the service using environment variables, then `exec` the real service so it runs as PID 1 in the foreground.
- `docker-compose.yml` builds the three images, creates the network and volumes, and sets the restart policy.
- The `Makefile` wraps everything so the whole stack is built and started with one command.

### Main design choices

- **Debian 12 as the base image.** Debian was chosen over Alpine for more predictable package names and behaviour for MariaDB, php-fpm and nginx.
- **No daemon hacks.** Each container runs its service directly in the foreground (`mysqld`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`) instead of using `tail -f`, `sleep infinity` or similar tricks.
- **Initialisation at runtime, not build time.** Database users, passwords and the WordPress install are set up by the entrypoint scripts at first start, so no credential is ever baked into an image.
- **Initialisation only once.** The scripts check whether the data already exists (`/var/lib/mysql/mysql`, `wp-config.php`), so restarts do not wipe or redo the setup.
- **TLS only.** nginx accepts HTTPS on port 443 only, with a self-signed certificate generated at build time.

### Comparisons

**Virtual Machines vs Docker**
A virtual machine emulates hardware and runs a full guest operating system with its own kernel, so it is heavy to start and uses a lot of RAM and disk. A Docker container is just an isolated process (or group of processes) that shares the host's kernel and only ships the userland files it needs. Containers start in seconds and are much lighter, but they are less isolated than a VM since the kernel is shared. In this project the VM is the host that gives a safe, disposable environment, and Docker splits the application into small services inside it.

**Secrets vs Environment Variables**
Environment variables are simple and good for non-sensitive configuration (domain name, database name, site title). The downside is that they are visible in `docker inspect`, in `/proc` inside the container, and are easily leaked by logs or child processes. Docker secrets are mounted as files in `/run/secrets/` inside only the containers that need them, are not stored in the image, and are not shown by `docker inspect`. This project keeps all its configuration, passwords included, in a local `srcs/.env` file that Compose passes to the containers through `env_file`. Moving the passwords to Docker secrets would be the more secure option.

**Docker Network vs Host Network**
With a dedicated Docker (bridge) network, containers get their own private network, can reach each other by service name through Docker's built-in DNS, and only the ports that are explicitly published are reachable from outside. With host networking the container shares the host's network stack directly: there is no isolation and no port mapping, and port conflicts with the host become possible. This project uses a custom bridge network, and only nginx publishes a port (443). `network: host` and `links` are forbidden by the subject.

**Docker Volumes vs Bind Mounts**
A bind mount maps an exact host path into the container and depends on that host directory's layout and permissions. A named volume is created and managed by Docker, referenced by name, and is independent of the container lifecycle. This project uses named volumes (`mariadb_vol`, `wordpress_vol`) as required by the subject. Their `driver_opts` place the data under `/home/<login>/data` on the host (the `DATA_PATH` variable in `srcs/.env`), so the files are easy to find while Docker still manages them as volumes.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin installed
- `make`
- A line in `/etc/hosts` pointing the domain to the machine's IP:

```
127.0.0.1   ybarakat.42.fr
```

### Setup

1. Clone the repository.
2. Create `srcs/.env` (see `DEV_DOC.md` for the full list of variables).
3. Build and start everything:

```
make
```

4. Open `https://ybarakat.42.fr` in a browser (accept the self-signed certificate warning).

### Makefile targets

| Command      | Effect                                                         |
|--------------|----------------------------------------------------------------|
| `make`       | Create the data folders, build the images and start the stack  |
| `make down`  | Stop and remove the containers (data is kept)                  |
| `make clean` | Remove the containers, images and volumes                      |
| `make fclean`| `clean` + delete the data stored on the host                   |
| `make re`    | `fclean` then rebuild from scratch                             |

More detail is in `USER_DOC.md` (using the stack) and `DEV_DOC.md` (developing on it).

## Resources

### References

- Docker documentation: https://docs.docker.com/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker Compose file reference: https://docs.docker.com/reference/compose-file/
- Best practices for writing Dockerfiles (PID 1, layers, caching): https://docs.docker.com/build/building/best-practices/
- NGINX documentation (SSL/TLS, FastCGI): https://nginx.org/en/docs/
- PHP-FPM manual: https://www.php.net/manual/en/install.fpm.php
- MariaDB Knowledge Base: https://mariadb.com/kb/en/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/

### Use of AI

- **Learning:** explaining Docker concepts (images vs containers, layers, PID 1, volumes vs bind mounts, networks, `CMD` vs `ENTRYPOINT`), what php-fpm and FastCGI are, and how MariaDB users and privileges work.
- **Documentation:** helping with the structure of this README, `USER_DOC.md` and `DEV_DOC.md`
