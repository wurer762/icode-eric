# loadbalancer

Installs HAProxy and balances HTTP round-robin over all hosts of an inventory group, with a stats page.

## Variables
| Variable | Default | Meaning |
|---|---|---|
| `lb_port` | `80` | Frontend port |
| `lb_backend_group` | `web` | Inventory group of the backend servers; each needs `ansible_host` and `web_port` in its hostvars |
| `haproxy_stats_port` | *(required)* | Port of the stats page |
| `haproxy_stats_user` / `haproxy_stats_password` | *(required)* | Login for the stats page |

## Example
```yaml
- hosts: lb
  become: true
  roles:
    - loadbalancer
```
