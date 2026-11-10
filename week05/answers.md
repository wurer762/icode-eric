# Week 5 — Answers

## Part A
**Q1.** It contacts worker1, worker2 and worker3. `workers` is a parent group (`[workers:children]`), so it contains every host of its child groups `web` and `lb`.

**Q2.** For the manager it shows `"server_role": "VARIABLE IS NOT DEFINED!"`. The manager is only in `managers` (and `all`), and `server_role` is only defined in `group_vars/web.yml` and `group_vars/lb.yml`.

**Spot the mistake.** The files in `group_vars/` were named differently from the groups in the inventory (or the folder name was misspelled). Ansible only loads `group_vars/<group>.yml` when `<group>` matches a group name in the inventory exactly. Likewise, `host_vars/<host>.yml` must match the inventory host name (e.g. `worker1`), not the IP or DNS name.

## Part B
**Q3.** Ansible shows one result line per element, e.g. `changed: [worker1] => (item={'name': 'alice', 'comment': 'Alice Admin'})`. In each round, `item` is the current dictionary from the `admins` list, so `item.name` and `item.comment` are that admin's values.

**Q4.** dave was removed again from worker2, together with his home directory (`remove: true`). With `state: absent`, Ansible actively makes sure the account does not exist. If you only deleted his line, Ansible would stop managing him and an existing account would stay on the servers.

**Q5.** It uses the `state` of the current admin if it is defined, and `present` otherwise.

## Part C
**Q6.** worker3 got htop, curl, vim, git, qemu-guest-agent and haproxy. The list is `common_packages` (from `group_vars/all.yml`) + `extra_packages` (from `group_vars/lb.yml`, since worker3 is in `lb`). `default([])` avoids an error on hosts without `extra_packages`.
## Part D
**Q8.** The kernel task now reports `changed` on every run, so the recap shows `changed=1` per host even though nothing was modified. That is misleading: a second run should show `changed=0` (idempotence), and a read-only command never changes anything.

## Part E
| Host    | My prediction    | Result without -e | Result with -e |
|---------|------------------|-------------------|----------------|
| worker1 | Alice            | Alice             | command-line   |
| worker2 | the web team     | the web team      | command-line   |
| worker3 | the ICODE class  | the ICODE class   | command-line   |

**Q9.** The most specific definition wins: `-e` beats `host_vars/<host>.yml`, which beats `group_vars/<group>.yml`, which beats `group_vars/all.yml`.

## Review questions
**Q10.** worker1 → 8080 (web group), worker2 → 8081 (host_vars beats group_vars), worker3 → 80 (only in `all`).

**Q11.** A fact is collected automatically from the host by Gathering Facts, e.g. `ansible_distribution` or `ansible_memtotal_mb`. A variable you define is set by you in your files, e.g. `timezone` in `group_vars/all.yml`.

**Q12.** In YAML, a value starting with `{` is read as a dictionary, so `msg: {{ inventory_hostname }}` is a syntax error. It must be quoted: `msg: "{{ inventory_hostname }}"`. `when:` is already a raw Jinja2 expression, so Ansible evaluates it directly without `{{ }}`.
