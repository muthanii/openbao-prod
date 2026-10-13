# OpenBao: single-node production setup

One OpenBao server in Docker Compose, with Raft storage, TLS, a file audit log,
an admin policy and nightly snapshots. Tested with OpenBao 2.7.1.

Run it on a Linux VM with Docker. Do steps 1 to 7 once. Do "After every restart"
each time the container or host restarts.

## 1. Prepare the host

- Turn swap off (`sudo swapoff -a`, and remove the swap line from `/etc/fstab`).
  Secrets in memory must not be written to disk.
- Copy this folder to the server, for example to `/opt/openbao`.

## 2. Set the version and the address

```bash
cp .env.example .env      # set OPENBAO_VERSION=2.7.1 (or the latest release)
```

In `config/openbao.hcl`, set `api_addr` to the name clients will use, for example
`https://bao.teebatkarbala.local:8200`. Add that name to DNS.

## 3. Certificates

Production: get a certificate for that name from the internal CA. Put `tls.crt`,
`tls.key` and `ca.crt` in `tls/`. The certificate must also include `127.0.0.1`.

Test VM only:

```bash
./scripts/gen-test-certs.sh bao.teebatkarbala.local <server-ip>
```

## 4. Start and initialise

```bash
docker compose up -d
docker compose exec openbao bao status          # Initialized false, Sealed true
docker compose exec openbao bao operator init -key-shares=5 -key-threshold=3
```

The output holds 5 unseal keys and a root token. It is shown once.

- Give one unseal key to each of 5 people. Any 3 of them can unseal the server.
  Each person keeps their key offline (a sealed envelope in a safe, or their own
  password manager). Never store all keys in one place, and never in OpenBao.
- Keep the root token only until step 7.

## 5. Unseal

Three key holders run this, one after the other, each pasting their own key:

```bash
docker compose exec openbao bao operator unseal
```

`bao status` then shows `Sealed false`.

## 6. First configuration (with the root token)

```bash
docker compose exec openbao bao login            # paste the root token

# Policies
docker compose exec -T openbao bao policy write admin    - < policies/admin.hcl
docker compose exec -T openbao bao policy write snapshot - < policies/snapshot.hcl

# Admin accounts (one per person; move to LDAP/AD later)
docker compose exec openbao bao auth enable userpass
docker compose exec openbao bao write auth/userpass/users/<name> \
	password='<strong password>' token_policies=admin

# A store for API keys and other static secrets, with version history
docker compose exec openbao bao secrets enable -path=secret kv-v2

# Token for backups: can take snapshots and nothing else
docker compose exec openbao bao token create -policy=snapshot -period=768h -orphan
```

Check that the audit log is on: `docker compose exec openbao bao audit list` shows `file/`.
Secret values in the log are hashed, not written in clear.

## 7. Revoke the root token

Log in with an admin account and confirm it works first. Then:

```bash
docker compose exec openbao bao token revoke <root token>
```

## Backups

```bash
BAO_SNAPSHOT_TOKEN=<token from step 6> ./scripts/backup.sh
```

Schedule it nightly with cron (see the top of `scripts/backup.sh`), and copy
`/var/backups/openbao` to another machine. It keeps the last 14 snapshots.

A snapshot is encrypted. Restoring it needs the **original unseal keys**, so a
backup without the key holders is useless, and the reverse.

Test a restore once before relying on it:

1. On a test VM, start an empty server and initialise it (any key count).
2. Unseal it, log in with its root token, then:
   `bao operator raft snapshot restore -force <file>.snap`
3. The server seals itself. Unseal it with 3 of the **original** keys.
4. Log in with an original admin account and read a secret.

## After every restart

The server starts sealed and answers nothing until 3 key holders run step 5.
Applications that read secrets will fail until then, so make sure enough key
holders can be reached at any time, and that applications keep running for a
while with the credentials they already hold.

## Getting a root token back

Needed for recovery or for changes the admin policy cannot make. It always
needs 3 key holders:

```bash
docker compose exec openbao bao operator generate-root -init      # prints an OTP
docker compose exec openbao bao operator generate-root            # each of 3 holders
docker compose exec openbao bao operator generate-root -decode=<encoded> -otp=<otp>
```

Revoke it again when done.

## Upgrades

Take a snapshot, change `OPENBAO_VERSION` in `.env`, run `docker compose up -d`,
then unseal. Read the release notes first.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `permission denied` on `tls.key` in `docker compose logs` | The container user cannot read the key. Make it readable by that user, for example `chmod 644 tls/tls.key` on a server where only admins have a login. |
| `x509: certificate is valid for …, not …` | The name in `BAO_ADDR` or `api_addr` is not in the certificate. Reissue it with that name and `127.0.0.1`. |
| `cannot enable audit device via API` | Expected in OpenBao 2.x. Audit devices are set in `config/openbao.hcl` only. |
| Everything returns 503 | The server is sealed. Unseal it (step 5). |
