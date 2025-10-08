# cuac

Apache Guacamole - in Docker, behind caddy, with backup scripts and restoration steps.

Assumption is that Caddy is already running in Docker, and that it is connected to Docker network named `caddy`

## Create dirs

Go to the repo folder, e.g. `cd ~/containers/guac` and create directories:

```sh
mkdir -p $PWD/{recordings,db,backups,secrets}
```

## Create a local .env

Go to the repo folder, e.g. `cd ~/containers/guac` and create a local .env file from the template file, then adjust the variables with correct values (.env is in .gitignore file and will not be committed):

```sh
cp $PWD/.env.template $PWD/.env
```

Edit: `nano $PWD/.env`

## Create secrets

Go to the repo folder, e.g. `cd ~/containers/guac` and create the secrets

```sh
mkdir -p $PWD/secrets
echo "guacuser" > $PWD/secrets/db_user
openssl rand -base64 32 > $PWD/secrets/db_password
chmod 600 $PWD/secrets/*
```

## Caddy configuration

Add the snippet in `./caddy/Caddyfile_snippet.txt` to your main Caddyfile. Change "guac.example.com" to actual url.

Reload the CaddyFile:

```sh
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## Initialize + start

Go to the repo folder, e.g. `cd ~/containers/guac`

```sh
docker compose up -d

# One-time schema init:
docker exec guacamole /opt/guacamole/bin/initdb.sh --postgres \
  | docker exec -i guac-postgres psql \
      -U "$(cat $PWD/secrets/db_user)" \
      -d "$(grep POSTGRES_DB $PWD/.env | cut -d= -f2)"
```

## Backup script (reads passwords from secrets)

Go to the repo folder, e.g. `cd ~/containers/guac`.

Backup script is located in the scripts folder. Make it executable and test:

```sh
chmod +x $PWD/scripts/backup_guac.sh
$PWD/scripts/backup_guac.sh
```

Backup should be done regularly. Add a cron if you want (logs go to backups/backup.log):

(crontab -l 2>/dev/null; echo "17 3 * * * $HOME/containers/guac/scripts/backup_guac.sh >> $HOME/containers/guac/backups/backup.log 2>&1") | crontab -

## Restore script and steps

### From scratch (i.e. new host)

Go to the repo folder, e.g. `cd ~/containers/guac`.

Just create new secrets (new values are fine):

```sh
echo "guacuser" > $PWD/secrets/db_user
openssl rand -base64 32 > $PWD/secrets/db_password
chmod 600 $PWD/secrets/*
```

Recreate the stack fresh and restore (provide the correct backup name):

```sh
docker compose down
sudo rm -rf $PWD/db/*          ### make sure you are in the right place, this is irreversible!!!
docker compose up -d
sleep 5

# restore config + recordings from your tarball
tar xzf $PWD/backups/guac_YYYY-MM-DD_HHMMSS.tar.gz -C .
docker exec -i -e PGPASSWORD="$(cat secrets/db_password)" guac-postgres \
  psql -U "$(cat $PWD/secrets/db_user)" -d "$(grep POSTGRES_DB $PWD/.env | cut -d= -f2)" \
  < $PWD/backups/guacamole_db.sql
docker compose restart
```

## Only restore backups

Go to the repo folder, e.g. `cd ~/containers/guac`.

Restore script is located in the scripts folder. Make it executable and test:

```sh
chmod +x $PWD/scripts/restore_guac.sh
```

Run it like this (provide the correct backup name):

```sh
$PWD/scripts/restore_guac.sh ~/guac/backups/guac_2025-10-08_031500.tar.gz
```

## Security summary

- .env, secrets/, db/, backups/, recordings/ are ignored by git.
- All credentials come from untracked files.
- Caddy provides TLS; no ports exposed to the host.
- Database is isolated inside Docker’s private network.
- If you add SSH keys inside Guacamole, remember they are stored reversibly in the DB — keep DB access restricted.
