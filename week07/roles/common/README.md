# common

Baseline for every server: packages, time zone, message of the day, admin users with SSH keys, passwordless sudo for `admins`, and `PermitRootLogin no`.

## Variables (defaults/main.yml)
| Variable | Default | Meaning |
|---|---|---|
| `timezone` | `UTC` | System time zone |
| `common_packages` | `[htop, curl]` | Packages for every host |
| `extra_packages` | `[]` | Extra packages per group |
| `admins` | `[]` | List of `{name, comment, state}`; `state: absent` removes the user and their home |
| `motd_owner` | `the IT team` | Shown in `/etc/motd` |
| `server_role` | `server` | Shown in `/etc/motd` |

Each present admin needs `files/<name>.pub`.

## Requirements
Collections `community.general` and `ansible.posix` (see `requirements.yml`).

## Example
```yaml
- hosts: workers
  become: true
  roles:
    - common
```
