# Week 8 — Answers

> The vault password is in `~/.vault_pass` on the manager (mode 600, outside the repository). The DB password in `group_vars/db/vault.yml` was generated randomly and has never been printed. To see it: `ansible-vault view group_vars/db/vault.yml`.

## Part A — Ansible Vault basics

**Q1.** `cat` shows no readable content, only a header line and lines of hexadecimal ciphertext:
```
$ANSIBLE_VAULT;1.1;AES256
61633335393566313539336563353232316635666463343965333334306662613333663961616131
3865326564336462316566386636353937366337653732330a6630323137623230343061...
```
The first line is the vault header. `$ANSIBLE_VAULT` marks the file as encrypted by Ansible Vault (so Ansible decrypts it automatically when it loads the file), `1.1` is the vault format version, and `AES256` is the cipher (AES with a 256-bit key, derived from the vault password). Version 1.2 would add a vault ID label, e.g. `;dev`.

**Q2.** The encryption is only as secret as the password. If `~/.vault_pass` were in the repository, anyone who can read the repo could decrypt every secret, and the encryption would be pointless. Keeping it outside the repo (in my home folder, `chmod 600`, and `.vault_pass*` in `.gitignore`) separates the lock (in Git) from the key (only on the manager).
If I lose it, the encrypted files can't be decrypted any more. There is no "reset password" or back door, because AES-256 can't be brute-forced. I would have to set new secrets (new DB password, etc.), encrypt them again with a new vault password, and change them on the servers. So the vault password itself needs a safe backup, e.g. in a password manager.

## Part B — The vault pattern

**Q3.** `ansible db -m debug -a "var=db_password"` prints the password in clear text: `"db_password": "<the real password>"`. Vault protects secrets **at rest**: the file in Git, on GitHub, in backups and on a stolen laptop is unreadable without the vault password.
It does **not** protect them **in use**. As soon as Ansible runs with the vault password, the values are decrypted in memory, and anyone who can run Ansible on the manager can print them, in debug output, `-v` logs, error messages, or in the rendered files on the servers (`/etc/haproxy/haproxy.cfg`, the DB config). That's why `no_log` and file permissions are also needed.

**Q4.** With the split, `vars.yml` stays readable. Anyone can `grep` it, review it in a pull request, and see *which* variables exist (`db_password` → `vault_db_password`) without the vault password. `vault.yml` contains only the secret values. The `vault_` prefix shows where a value comes from.
If `vars.yml` were encrypted as a whole, every `grep` would miss it, `git diff` would show only changed ciphertext, and you would need the vault password just to read harmless values like `db_name`. Reviews and troubleshooting get much harder.

## Part C — The database role

**Q5.** `SHOW DATABASES` → `icode`, plus the system databases `information_schema`, `mysql`, `performance_schema` and `sys`.
`SELECT user, host FROM mysql.user` → `icode_app@%` (later restricted, see the challenge), plus the built-in `mariadb.sys@localhost`, `mysql@localhost` and `root@localhost`.
On Ubuntu, MariaDB's `root@localhost` uses **unix_socket authentication**: the OS user `root` connecting over the local socket is let in without a password. The tasks run with `become: true` (as root) on the DB server, so `login_unix_socket: /run/mysqld/mysqld.sock` works without any root password. No root DB password has to be created, stored in the vault or sent over the network, and root can't log in over TCP at all.

**Q6.** Without `no_log`, the debug task prints the secret in clear text: `ok: [worker3] => {"msg": "The password is <password in clear text>"}` (in my notes it is masked). With `no_log: true` the output is only `ok: [worker3]`. The message is hidden, and the same goes for `-v` output and logs.
The task **"Create the application user"** already has `no_log: true`. It passes `password: "{{ db_password }}"` to `mysql_user`, and Ansible's task result (module arguments shown with `-v`, the "changed" result and error messages) could otherwise contain the password.

**Q7.** Before, `/etc/mysql/mariadb.conf.d/50-server.cnf` had **`bind-address = 127.0.0.1`** (checked in the original file from the `.deb` package). MariaDB listened only on localhost, so it accepted no connections from the network. Now it's `bind-address = 0.0.0.0` (`ss -ltn` shows `0.0.0.0:3306`).
Without the change, the client on worker1 would have got **connection refused**: `ERROR 2002 (HY000): Can't connect to server on '10.0.97.42' (115)` (errno 115 is the refused TCP connection). The login itself (`SELECT DATABASE(), CURRENT_USER();` → `icode | icode_app@%`) only worked because of the bind-address task.

## Part D — Code quality with ansible-lint

**Q8.** `ansible-lint bad.yml` (ansible-lint 6.17.2) reported 12 violations:

| Rule | Line | Meaning |
|---|---|---|
| `name[casing]` | 2 | Names should start with an uppercase letter (`quick fixes…`). |
| `yaml[truthy]` | 4 | Use `true`/`false`, not `yes`/`no`/`on` (ambiguous in YAML 1.2). |
| `fqcn[action-core]` | 6, 7 | Use the full name `ansible.builtin.apt` / `ansible.builtin.command`, so it's clear which collection's module runs. |
| `name[missing]` | 6 | Every task needs a `name:` (readable output, `--start-at-task`). |
| `no-free-form` | 6 | `name=nginx state=latest` is free-form `key=value`. Use real YAML arguments. |
| `package-latest` | 6 | `state: latest` upgrades on every run, which is unpredictable and not idempotent. Use `present`. |
| `no-changed-when` | 7, 13 | `command`/`shell` always report `changed`. Add `changed_when:` (or use a module). |
| `risky-file-permissions` | 9 | `copy` without `mode:`, so the file permissions depend on the umask. |
| `command-instead-of-module` | 13 | `systemctl` via shell. Use the `systemd`/`service` module. |
| `command-instead-of-shell` | 13 | `shell` without any shell features (pipes, redirects). `command` is safer. |

Fixed `bad.yml`: named play and tasks, `become: true`, FQCN everywhere, `apt` with `state: present` in YAML form, `command: nginx -v` with `changed_when: false`, `copy` with `owner`/`group`/`mode: "0644"`, and the reload as `ansible.builtin.systemd` with `state: reloaded`. Result: `Passed: 0 failure(s), 0 warning(s)`, with even the strictest `production` profile met.

**Q9.** `ansible-lint` on the whole project gave 20 findings, all in the role skeletons from `ansible-galaxy role init`, none in my tasks:

| Rule | Where | Decision |
|---|---|---|
| `meta-incorrect` (12×) | `roles/*/meta/main.yml`: `author`, `company`, `license` still had the template values | **Fixed**: real author, company, licence, description and platform (Ubuntu). |
| `schema[meta]` (4×) | `min_ansible_version: 2.1` is a float, not a string | **Fixed**: `min_ansible_version: "2.16"` (also the real minimum, ansible-core 2.16). |
| `name[play]` (4×) | `roles/*/tests/test.yml` have an unnamed play | **Fixed by removing** `tests/`: these generated test playbooks were never used (they just apply the role to `localhost`). |

After the fixes: `Passed: 0 failure(s), 0 warning(s) on 53 files`, profile `production`. No rule had to be skipped. `var-naming[no-role-prefix]` (shared `web_port`, `lb_port`, `page_color` without a role prefix) doesn't exist yet in ansible-lint 6.17.2. It was added in 6.18. I still put it into `.ansible-lint` with the reason, so newer linters (e.g. in a CI pipeline) skip it on purpose: the variables live in `group_vars` because several roles share them. `.ansible-lint` also sets `profile: production`, so the project must stay at the strictest level.

## Part E — Check mode, diff and tags

`--list-tags` shows `[base]`, `[always, web]` (argument-spec check), `[lb]` and `[db]`. `--tags db --check --diff` → worker3 `ok=7 changed=0`. `--tags web --check --diff` → `ok=9 changed=0` on all three web servers. With `--tags db`, worker1 and worker2 still show `ok=1`, because fact gathering in the first play is tagged `always`.

**Q10.** `--check` runs the playbook in simulation: modules report what they *would* change, without changing anything. `--diff` adds the actual line-by-line differences for files (templates, `copy`, `lineinfile`). Together they're a preview of the next run ("what exactly would change on which host"), which you can review before you run it for real.
- **Time saver:** after editing only the nginx template, `--tags web` runs only the web play, instead of waiting for apt, users and SSH on every worker.
- **Risk:** tags skip everything else, including tasks the tagged part depends on. E.g. `--tags db` on a fresh server skips the `base` play (packages, admin users, SSH hardening), and handlers or prerequisites in untagged tasks don't run. The server can end up half-configured, and a "green" run doesn't mean the whole site is correct.

## Challenge
- **`encrypt_string` for the HAProxy statistics password:** the plain-text `icode2026` from week 6 was already on GitHub, so it counts as burned. I generated a new random password and stored it inline in `group_vars/lb.yml` as `haproxy_stats_password: !vault | $ANSIBLE_VAULT;1.1;AES256 …`. Test: no login → 401, old `icode2026` → **401**, new password → **200**.
  Pitfall I hit: piping `openssl rand … | ansible-vault encrypt_string --stdin-name …` encrypts the **trailing newline** too, and the login then failed. It needs `tr -d '\n'` (or `printf '%s'`).
- **DB user only for the web servers:** `mysql_user` now loops over `groups[db_client_group]` (default `web`) with `host: "{{ hostvars[item]['ansible_host'] }}"`, and a second task removes `icode_app@%`. `mysql.user` now has `icode_app@10.0.97.38`, `@10.0.97.43` and `@10.0.97.42`. The login from worker1 shows `CURRENT_USER() = icode_app@10.0.97.38`. A wrong password → `ERROR 1045 (28000): Access denied`.
- **Two vault IDs (dev/prod):** not done.

## Review questions

**Q11.** No. The password is still in the Git history: the old commit can be checked out, it's in every clone and fork made in that hour, and bots scan GitHub for secrets within minutes. Deleting it in a new commit only hides it from the latest version. What must happen:
1. **Rotate it immediately:** change the password on every system that uses it and treat the old one as compromised. Check the logs for misuse in that hour.
2. Optionally clean the history (`git filter-repo`/BFG and a force-push, plus asking GitHub to purge cached views), but that doesn't make the secret safe again.
3. Prevent a repeat: put the new password in Ansible Vault, add `.gitignore` rules and a pre-commit/CI secret scanner.

**Q12.** A central secret manager stores secrets in **one place**, outside every repository. Access is controlled per person or machine, every read is **audited**, and a secret can be **rotated centrally** (even automatically or as short-lived dynamic credentials) without re-encrypting and committing files in every project. With Ansible Vault everyone with the vault password can read all secrets, and changing a password means editing, encrypting and redistributing files.

**Q13.** People forget, use different linter versions or skip it when they're in a hurry. A pipeline runs the **same** version and configuration on **every** change, automatically, before the merge. Problems are found before they reach `main` or the servers, the rules (and skips in `.ansible-lint`) are enforced the same way for everyone, and reviewers can focus on the logic instead of style.

**Q14.** Check mode only simulates each task on its own. It doesn't really change anything, so tasks that depend on an earlier change can't see it. Modules like `command`/`shell` are skipped or can't predict their result, and handlers don't really run.
Example from today: on the first run of the database play, `mariadb-server` and `python3-pymysql` were not installed yet. In check mode `apt` only *pretends* to install them, so `community.mysql.mysql_db` and `mysql_user` would fail: there's no MariaDB socket and no PyMySQL driver. (Same in week 4: bob's SSH key failed in check mode because his user only "would" exist.) The `--check` result of `--tags db` was only reliable today because the database already existed.
