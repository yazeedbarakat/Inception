# User Documentation

This document explains how to use the Inception stack as an end user or administrator. No Docker knowledge is needed beyond running a few commands.

## 1. What services are provided

The stack runs a WordPress website made of three services, each in its own container:

| Service     | What it does                                                         |
|-------------|----------------------------------------------------------------------|
| `nginx`     | The web server. It is the only service reachable from outside, over HTTPS (port 443). |
| `wordpress` | Runs the WordPress site (PHP). It is only reachable through nginx.   |
| `mariadb`   | The database where WordPress stores posts, pages, users and settings. |

Your website data survives restarts: the database and the WordPress files are kept in two persistent volumes stored under `/home/ybarakat/data/` on the host machine.

## 2. Start and stop the project

All commands are run from the root of the repository.

| Action                                          | Command      |
|-------------------------------------------------|--------------|
| Start everything (builds the images if needed)  | `make`       |
| Stop everything (your data is kept)             | `make down`  |
| Restart from scratch, **deleting all data**     | `make re`    |
| Remove everything including stored data         | `make fclean`|

After `make down` followed by `make`, the website comes back with all its content.

Containers are set to restart automatically if they crash.

## 3. Access the website and the administration panel

### One-time setup on your machine

Make the domain name point to the machine running the stack. Add this line to `/etc/hosts` (use the machine's IP address if you are connecting from another computer):

```
127.0.0.1   ybarakat.42.fr
```

### Website

Open in a browser:

```
https://ybarakat.42.fr
```

The certificate is self-signed, so the browser shows a security warning. This is expected: choose "Advanced" and continue. Only HTTPS is available; plain HTTP (port 80) is not served.

### Administration panel

```
https://ybarakat.42.fr/wp-admin
```

Log in with the WordPress administrator account (see the next section for where its credentials are).

## 4. Locate and manage credentials

Credentials are never stored in the images or in git. They are kept in local files that exist only on your machine:

| Where                 | What it contains                                              |
|-----------------------|---------------------------------------------------------------|
| `srcs/.env`           | Non-sensitive settings: domain name, database name, usernames, site title, admin email |
| `secrets/*.txt`       | Passwords (database user, database root, WordPress admin)    |

The WordPress administrator account is defined by:

- `WP_ADMIN_USER` (the login name)
- the matching admin password
- `WP_ADMIN_EMAIL`

The MariaDB users used by the stack are defined by `DB_ADMIN` / `DB_ADMIN_PASS` and `DB_USER` / `DB_USER_PASS`, and the root password by `DB_ROOT_PASS`.

### Changing a password

Database and WordPress accounts are created **only the first time** the containers start with empty data. Editing a password in the files afterwards does not change an existing account. To apply new values, either:

- change the password from inside WordPress (Users -> Profile) for the WordPress admin, or
- run `make re` to wipe everything and recreate it with the new values (**this deletes all site content**).

## 5. Check that the services are running correctly

**List the containers and their status**

```
docker compose -f srcs/docker-compose.yml ps
```

All three (`mariadb`, `wordpress`, `nginx`) should show as running ("Up").

**Quick check of each container**

```
docker ps
```

You should see `nginx`, `wordpress` and `mariadb`. Only nginx should show a published port (`0.0.0.0:443->443/tcp`).

**Check the website answers over HTTPS**

```
curl -k -I https://ybarakat.42.fr
```

A response with an HTTP status (such as `200` or `302`) means nginx and WordPress are working. (`-k` accepts the self-signed certificate.)

**Read the logs if something is wrong**

```
docker compose -f srcs/docker-compose.yml logs
docker compose -f srcs/docker-compose.yml logs wordpress
```

**Common problems**

| Symptom                                | Likely cause / fix                                                       |
|----------------------------------------|--------------------------------------------------------------------------|
| Browser cannot find the site           | Missing or wrong line in `/etc/hosts`                                    |
| "Connection refused"                   | The stack is not running: run `make`                                     |
| "Error establishing a database connection" | MariaDB is still starting or its credentials do not match: check `logs mariadb` |
| Browser security warning               | Normal: the certificate is self-signed                                   |
