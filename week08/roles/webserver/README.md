# webserver

Installs nginx, deploys the icode start page and site configuration, disables the default site.

## Variables (defaults/main.yml)
| Variable | Default | Meaning |
|---|---|---|
| `web_port` | `80` | Port nginx listens on (integer, checked by `meta/argument_specs.yml`) |
| `page_color` | `#0094C3` | Background colour of the start page |

The start page also lists `admins` (from the inventory). Set `web_port` in `group_vars/` when a load balancer needs to read it.

## Example
```yaml
- hosts: web
  become: true
  roles:
    - webserver
```
