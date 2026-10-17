# Inception: Review Guide

Everything for the defense: the 13 evaluation questions in order, what the evaluator checks, the commands to run, and the answers to the questions they usually ask.

Login: `ybarakat` | Domain: `ybarakat.42.fr` | Base image: `debian:12`

---

## 0. Before the defense (checklist)

- [ ] **`srcs/.env` is NOT in git.** If any password is in the repo, the review stops at 0 (Q1).
  - `git ls-files | grep .env` must print nothing.
  - `git log --all -p | grep -i pass` must not show real passwords (old commits count too).
- [ ] The defense runs **on the VM**, not on the host machine.
- [ ] Data path is `/home/ybarakat/data`: check `DATA_PATH` in `srcs/.env` **and** the paths in the `Makefile`.
- [ ] `/etc/hosts` on the VM contains `127.0.0.1   ybarakat.42.fr`.
- [ ] Docker starts at boot: `systemctl is-enabled docker` → `enabled`.
- [ ] Full rehearsal on a fresh clone: clone → create `srcs/.env` → `make` → site works.
- [ ] Rehearse a reboot (Q12) and a port change (Q13) once.
- [ ] Remember the passwords: you will log into WordPress and MariaDB live.

---

## 1. Preliminaries (Q1)

**Checked:** no credentials in the git repo, you are present, the right files are in the right place, they clone your repo onto their station.

**Commands they may run:**
```bash
git clone <repo> && cd <repo>
git ls-files                       # srcs/.env must not appear
git log --all -p | grep -i pass    # no real passwords in history
```

**Q: Where are your credentials stored?**
In `srcs/.env`, a local file that is never committed. Compose passes it to the containers with `env_file`. Nothing is written in the Dockerfiles or baked into the images.

**Q: Secrets vs environment variables?**
Env vars are visible in `docker inspect` and in the process environment (`/proc/<pid>/environ`). Docker secrets are mounted as files in `/run/secrets/` only in the containers that need them, and are not shown by `docker inspect`. Secrets are safer for passwords; I use `.env` (allowed by the subject, secrets are "strongly recommended", not mandatory).

---

## 2. General instructions (Q2): any failure ends the review

**First they clean everything:**
```bash
docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
```
Then you run `make`, and everything must rebuild from scratch.
Note: this does **not** delete `/home/ybarakat/data`, so WordPress will still be installed afterwards. That is normal.

| Check | Where in my project |
|---|---|
| Config files in `srcs/` at the root | `srcs/docker-compose.yml`, `srcs/.env`, `srcs/requirements/` |
| `Makefile` at the root | yes |
| No `network: host`, no `links:` | `grep -nE "host\|links" srcs/docker-compose.yml` → nothing |
| `networks` present in compose | `networks: inception` |
| No `--link` in Makefile/scripts | `grep -rn -- "--link" .` → nothing |
| No `tail -f`, no background `&` in ENTRYPOINT | entrypoints end with `exec mysqld` / `exec php-fpm8.2 -F`; nginx: `nginx -g "daemon off;"` |
| Penultimate stable Debian/Alpine | `FROM debian:12` (13 is current stable) |
| No infinite loops (`sleep infinity`, `while true`, `tail -f /dev/null`) | none |

```bash
grep -rnE "tail -f|sleep infinity|while true|--link|network_mode|links:" srcs Makefile
```

**Q: Why `exec` at the end of the entrypoint scripts?**
It replaces the shell with the service, so the service becomes **PID 1**. PID 1 receives the signals sent by `docker stop` (SIGTERM) and can shut down cleanly. Without `exec`, the shell is PID 1 and the signal never reaches the service.

**Q: Why `daemon off;` / `php-fpm -F`?**
A container lives as long as its main process. If the service forks into the background, PID 1 exits and the container stops. These flags keep the service in the foreground.

**Q: Isn't `mysqladmin ping --wait=30` a loop?**
No. It is a bounded retry (max 30 attempts) to wait for MariaDB before installing WordPress, then the script continues.

**Q: What does `mysqld --bootstrap <<EOF` do?**
Runs the setup SQL in the foreground and exits. Nothing stays in the background; then `exec mysqld` starts the real server.

**Q: What is PID 1 and why does it matter?**
The first process in the container. It must handle signals and reap zombie child processes. That is why the real service runs as PID 1, not a hacky `tail -f`.

---

## 3. Activity overview (Q3): explain in simple terms

**How Docker works:**
A Dockerfile is a recipe → `docker build` makes an **image** (read-only template) → `docker run` makes a **container** (a running, isolated process). Containers share the host kernel; isolation comes from Linux namespaces (processes, network, filesystem) and cgroups (CPU/RAM limits).

**How docker compose works:**
One YAML file describes several services, their network, volumes, env vars, restart policy and startup order. `docker compose up -d --build` builds and starts everything; `down` removes it. My Makefile just calls compose.

**Image with compose vs without:**
The image is the same. Without compose, I would run `docker build`, `docker network create`, `docker volume create` and a long `docker run ...` for each container, in the right order, by hand. Compose writes all of that once, declaratively, and is reproducible.

**Docker vs VM:**

| VM | Container |
|---|---|
| Emulates hardware, full guest OS with its own kernel | Shares the host kernel, isolates processes |
| GBs, boots in minutes | MBs, starts in seconds |
| Strong isolation | Weaker isolation, much lighter |

"In this project the VM isolates my environment, and Docker isolates each service inside it."

**Directory structure:**
```
Makefile                    single entry point: make
srcs/docker-compose.yml     orchestration
srcs/.env                   configuration, kept out of code and git
srcs/requirements/<service>/Dockerfile + conf/ + tools/
```
One folder per service = separate build context, independent images. `conf/` = config files, `tools/` = scripts.

---

## 4. README check (Q4): missing element ends the review

```bash
head -1 README.md       # *This activity has been created as part of the 42 curriculum by ybarakat*
grep -n "^#" README.md
```
Required: italic first line, **Description**, **Instructions**, **Resources** (with AI usage), Docker usage + sources + design choices, and the 4 comparisons: VM vs Docker, Secrets vs Env vars, Docker network vs Host network, Volumes vs Bind mounts.

**Q: How did you use AI?**
To learn concepts (images vs containers, PID 1, volumes, networks, FastCGI, MariaDB users) and to structure the documentation. Be ready to explain every line of the code yourself.

---

## 5. Documentation check (Q5): missing/empty ends the review

- `USER_DOC.md`: services, start/stop, website + admin panel, credentials, checking the services.
- `DEV_DOC.md`: prerequisites, setup (`.env`), Makefile, compose commands, where data lives.

---

## 6. Simple setup (Q6): failure ends the review

```bash
make
https://ybarakat.42.fr                  # in the browser: WordPress site, NOT the install page
curl -k -I https://ybarakat.42.fr       # HTTP 200
curl -I http://ybarakat.42.fr           # must FAIL: connection refused
docker ps                               # only nginx has 0.0.0.0:443->443
```

**Q: Why does `docker ps` show 9000/tcp and 3306/tcp?**
Those come from `EXPOSE`: reachable only inside the Docker network, not published to the host. Only nginx has `ports: "443:443"`.

**Q: Why is there a certificate warning?**
The certificate is self-signed (`openssl req -x509` in the nginx Dockerfile); no trusted CA signed it. The connection is still encrypted.

**Q: Why can't they see the install page?**
My WordPress entrypoint installs WordPress automatically with WP-CLI (`wp core install`) on first start.

---

## 7. Docker basics (Q7): failure ends the review

| Check | Command / answer |
|---|---|
| One non-empty Dockerfile per service | `ls srcs/requirements/*/Dockerfile` |
| Built myself, nothing from DockerHub | `docker image history mariadb:inception` shows my own layers |
| `FROM debian:12` | `grep FROM srcs/requirements/*/Dockerfile` |
| Image name = service name | `docker images` → `mariadb`, `nginx`, `wordpress` (tag `inception`) |
| Built via compose, no crash | `make`, then `docker compose -f srcs/docker-compose.yml ps` |

**Q: Isn't `mariadb` the official image?**
No. The `build:` key makes compose build it locally from my Dockerfile; `mariadb:inception` is just my name + tag. I never pull it.

**Q: Why Debian and not Alpine?**
More predictable package names and behaviour for mariadb, php-fpm and nginx. Alpine is smaller but uses musl and different package names.

**Q: Why not `latest`?**
Forbidden by the subject, and not reproducible: `latest` changes over time. A fixed version always builds the same thing.

**Q: CMD vs ENTRYPOINT?**
ENTRYPOINT is the fixed program the container runs; CMD gives default arguments (or the default command if there is no ENTRYPOINT) and is easily overridden by `docker run <image> <cmd>`.

**Q: RUN vs CMD?**
RUN executes at **build** time and creates a layer. CMD/ENTRYPOINT execute at **container start**.

**Q: What is a layer / build cache?**
Each instruction creates a read-only layer. Unchanged layers are reused from cache, which is why rebuilds are fast.

---

## 8. Docker network (Q8): failure ends the review

```bash
grep -n -A3 networks srcs/docker-compose.yml
docker network ls                         # srcs_inception (bridge)
docker network inspect srcs_inception    # the 3 containers with their IPs
docker exec wordpress getent hosts mariadb   # name resolution works
```

**Simple explanation to give:**
"A Docker network is a private virtual network for my containers. All three are attached to `inception`. Docker gives it a built-in DNS, so containers reach each other by service name: nginx uses `wordpress:9000`, WordPress uses `DB_HOST=mariadb`. From outside, only port 443 on nginx is reachable."

**Q: Why is it called `srcs_inception`?**
Compose prefixes resources with the project name, which is the name of the folder containing the compose file (`srcs`).

**Q: Why not `network: host`?**
The container would share the host's network stack: no isolation, MariaDB and php-fpm exposed, port conflicts. Forbidden by the subject.

**Q: Why not `links`?**
Legacy feature; user-defined networks already provide DNS between containers. Forbidden by the subject.

**Q: What is the bridge driver?**
A virtual switch on the host. Each container gets a virtual interface and an IP on it; Docker uses NAT for outgoing traffic and published ports.

---

## 9. NGINX with SSL/TLS (Q9): failure ends the review

```bash
docker compose -f srcs/docker-compose.yml ps     # or: docker compose -p srcs ps
curl -I http://ybarakat.42.fr                    # connection refused
openssl s_client -connect ybarakat.42.fr:443 -tls1_2 </dev/null | grep "New, TLS"   # TLSv1.2
openssl s_client -connect ybarakat.42.fr:443 -tls1_3 </dev/null | grep "New, TLS"   # TLSv1.3
```
Note: plain `docker compose ps` from the repo root fails (the compose file is in `srcs/`). Use `-f` or `-p srcs`.
In the browser: padlock → connection details shows TLS 1.3.

**My nginx config (`srcs/requirements/nginx/conf/nginx.conf`):**
- `listen 443 ssl;`: the only port, with TLS
- `ssl_protocols TLSv1.2 TLSv1.3;`: older protocols refused
- `ssl_certificate` / `ssl_certificate_key`: files generated in the Dockerfile
- `root /var/www/html;`: same volume as WordPress, so nginx serves static files directly
- `location ~ \.php$ { fastcgi_pass wordpress:9000; }`: PHP requests go to php-fpm over FastCGI

**Certificate generation (nginx Dockerfile):**
`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ... -out ... -subj "/CN=ybarakat.42.fr"`
- `-x509`: self-signed certificate (not a signing request)
- `-nodes`: private key not encrypted, so nginx starts without a passphrase
- `-days 365`: valid one year
- `rsa:2048`: 2048-bit RSA key

**Q: What is TLS?**
The protocol that encrypts HTTP traffic (HTTPS). The server proves its identity with a certificate; then client and server agree on keys and encrypt everything.

**Q: Why no redirect from 80 to 443?**
The subject says port 443 **only**. Opening port 80, even for a redirect, would break that.

**Q: What is FastCGI / php-fpm?**
nginx cannot execute PHP. php-fpm is a PHP process manager listening on port 9000; nginx forwards `.php` requests to it using the FastCGI protocol and returns the result.

---

## 10. WordPress + php-fpm + volume (Q10): failure ends the review

```bash
grep -i nginx srcs/requirements/wordpress/Dockerfile    # nothing
docker compose -f srcs/docker-compose.yml ps
docker volume ls
docker volume inspect srcs_wordpress_vol    # Options.device = /home/ybarakat/data/wordpress
docker exec wordpress wp user list --allow-root
```
Live test: log in as the regular user (`user`, role author) and post a comment; log in as admin at `https://ybarakat.42.fr/wp-admin`, edit a page, check the change on the site.

**Important:** in `docker volume inspect`, `Mountpoint` shows `/var/lib/docker/volumes/...`. The host path they look for is under **`Options` → `device`**. Point it out.

**Q: Is that a bind mount?**
No. It's a **named volume**: declared under `volumes:`, managed by Docker, listed by `docker volume ls`. The `local` driver options (`type: none, o: bind, device: ...`) only tell Docker where on the host to store its data. A bind mount would be `- /home/x/data:/var/www/html` directly in the service and would not appear in `docker volume ls`.

**Q: How is WordPress installed?**
The entrypoint, on first start (no `wp-config.php`): waits for MariaDB → `wp core download` → `wp config create` → `wp core install` (admin) → `wp user create ... --role=author` (second user). Then `exec php-fpm8.2 -F`.

**Q: Why does php-fpm listen on `0.0.0.0:9000`?**
By default it listens on a unix socket, which another container cannot reach. The entrypoint changes it with `sed` so nginx can reach it over the network.

**Q: Why the `chown -R www-data`?**
php-fpm runs as `www-data`; it must own the files to handle uploads, plugins and page edits.

**Q: Admin username rule?**
Must not contain admin/Admin/administrator. Mine is `ybarakat`.

---

## 11. MariaDB + volume (Q11): failure ends the review

```bash
grep -i nginx srcs/requirements/mariadb/Dockerfile   # nothing
docker volume inspect srcs_mariadb_vol               # Options.device = /home/ybarakat/data/mariadb
```

**How to log in (type the password when asked):**
```bash
docker exec -it mariadb mariadb -u root -p
docker exec -it mariadb mariadb -u user -p inception
```
```sql
SHOW DATABASES;
USE inception;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
SELECT post_title FROM wp_posts WHERE post_type='page';
SELECT comment_author, comment_content FROM wp_comments;   -- the comment from Q10
EXIT;
```
Good demo: show the comment and page edit from Q10 inside the database.
Bonus: `docker exec mariadb mariadb -u root` (no password) is **denied**: root is protected.

**Q: How is the database initialised?**
On first start (no `/var/lib/mysql/mysql`): `mariadb-install-db` creates the system tables, then `mysqld --bootstrap` runs SQL: remove anonymous users, set root password, create database `inception`, create `user`@`'%'` and grant it privileges on that database. Then `exec mysqld` as PID 1.

**Q: Why `'%'` as host for the user?**
WordPress connects from another container (another IP), so the user must be allowed from any host, not only localhost.

**Q: Why `bind-address = 0.0.0.0`?**
By default MariaDB listens only on 127.0.0.1, unreachable from the WordPress container. Port 3306 is still not published, so it's only open inside the Docker network.

**Q: Why `rm -rf /var/lib/mysql/*` in the Dockerfile?**
The Debian package creates a default database at install time. Removing it lets the entrypoint detect the first run and set up my users and passwords.

---

## 12. Persistence (Q12): failure ends the review

```bash
sudo reboot
# after boot
cd ~/Inception && make
docker compose -f srcs/docker-compose.yml ps
# browser: https://ybarakat.42.fr → edited page and comment are still there
```

**Why it works:**
- Data lives on the host in `/home/ybarakat/data/{mariadb,wordpress}`, not inside the containers.
- `restart: always` + Docker enabled at boot → containers come back by themselves.
- Entrypoints see existing data (`/var/lib/mysql/mysql`, `wp-config.php`) and skip the setup.

**Q: What does `restart: always` do?**
Restarts the container if it crashes, and when the Docker daemon starts (after reboot). Exception: a container you stopped manually.

**Q: What happens to the data with each make target?**
- `make down`: containers removed, data kept.
- `make clean`: containers, images and volumes removed; files in `/home/ybarakat/data` remain and are reused.
- `make fclean` / `make re`: host data deleted → fresh install.

---

## 13. Configuration modification (Q13): failure ends the review

They choose a service and a new port. You change it, rebuild with `make down && make`, and show it works.

### nginx: 443 → 8443 (most likely)
| File | Change |
|---|---|
| `srcs/requirements/nginx/conf/nginx.conf` | `listen 8443 ssl;` |
| `srcs/docker-compose.yml` | `ports: - "8443:8443"` |
| nginx `Dockerfile` | `EXPOSE 8443` |
```bash
make down && make
curl -k -I https://ybarakat.42.fr:8443
```
Shortcut: only `"8443:443"` in compose also works. Left = host port, right = container port.

### WordPress / php-fpm: 9000 → 9001
| File | Change |
|---|---|
| `srcs/requirements/wordpress/tools/entrypoint.sh` | `listen = 0.0.0.0:9001` in the `sed` |
| `srcs/requirements/nginx/conf/nginx.conf` | `fastcgi_pass wordpress:9001;` |
| wordpress `Dockerfile` | `EXPOSE 9001` |

Rebuild both images (`make down && make`).

### MariaDB: 3306 → 3307 (the tricky one)
| File | Change |
|---|---|
| `srcs/requirements/mariadb/tools/entrypoint.sh` | `exec mysqld --user=mysql --port=3307` |
| mariadb `Dockerfile` | `EXPOSE 3307` |
| WordPress config | `DB_HOST` must become `mariadb:3307` |

**Trap:** `wp-config.php` already exists in the volume, so changing `.env` does nothing. Update it directly:
```bash
make down && make
docker exec wordpress wp config set DB_HOST mariadb:3307 --allow-root
```
(If `mysqladmin ping -h $DB_HOST` is reached on a fresh install, it needs `-h mariadb -P 3307`.)

---

## Command cheat sheet

```bash
# Stack
make                    # build + start
make down               # stop (data kept)
make clean              # + remove images and volumes
make fclean             # + delete host data
make re                 # fclean + all

# Status and logs
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f
docker compose -f srcs/docker-compose.yml logs mariadb
docker ps
docker images
docker stats --no-stream

# Inside containers
docker exec -it wordpress bash
docker exec -it mariadb mariadb -u root -p
docker exec wordpress wp user list --allow-root
docker exec <container> ps aux          # PID 1 is the service itself
docker exec <container> env             # env vars received from .env

# Images
docker image history nginx:inception
docker inspect nginx

# Network and volumes
docker network ls
docker network inspect srcs_inception
docker volume ls
docker volume inspect srcs_mariadb_vol
docker volume inspect srcs_wordpress_vol
ls -la /home/ybarakat/data/*

# TLS / HTTP checks
curl -k -I https://ybarakat.42.fr
curl -I http://ybarakat.42.fr
openssl s_client -connect ybarakat.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect ybarakat.42.fr:443 -tls1_3 </dev/null
```

---

## Other questions evaluators like to ask

- **What is a container, in one sentence?** An isolated process with its own filesystem, network and process tree, sharing the host kernel.
- **Namespaces vs cgroups?** Namespaces isolate what a process can *see* (PIDs, network, mounts, hostname); cgroups limit what it can *use* (CPU, memory, I/O).
- **What does `depends_on` guarantee?** Only the start order, not that the service is ready. That's why WordPress waits for MariaDB with `mysqladmin ping`.
- **What is `.dockerignore`?** Like `.gitignore`, for the build context: files listed there are not sent to `docker build`.
- **Why is `.env` not copied into the image?** Compose injects the variables at container start with `env_file`, so no password is ever stored in an image layer.
- **What does `EXPOSE` do?** Documents the port the service listens on. It doesn't publish anything; `ports:` in compose does.
- **What is `docker compose up -d --build`?** `-d` runs in the background (detached), `--build` rebuilds images before starting.
- **Difference between `down` and `stop`?** `stop` stops containers; `down` stops and removes containers and the network (`-v` also removes volumes).
- **How do you see why a container crashed?** `docker compose -f srcs/docker-compose.yml logs <service>` and `docker ps -a` for the exit code.
- **Where are WordPress settings stored?** `wp-config.php` in the WordPress volume (DB connection); everything else (posts, users, options) in MariaDB.
