# database

Installs MariaDB, makes it listen on the network, and creates one application database with a user.
Requires the collection `community.mysql` (see `requirements.yml`).

## Variables (defaults/main.yml)
| Variable | Default | Meaning |
|---|---|---|
| `db_name` | `app` | Application database |
| `db_user` | `app` | Application user |
| `db_password` | *(required)* | Password of `db_user`. Keep it in Ansible Vault (`group_vars/db/vault.yml`) |
| `db_bind_address` | `0.0.0.0` | Address MariaDB listens on |
| `db_client_group` | `web` | Inventory group whose hosts (`ansible_host`) may log in as `db_user` |

The role logs in as root through the unix socket, so no root password is needed.

## Example
```yaml
- hosts: db
  become: true
  roles:
    - database
```
