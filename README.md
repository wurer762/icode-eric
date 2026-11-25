# ICODE lab work
Eric - Class: ICODE-CLASS

This repository holds my ICODE lab work (Git, Ansible, Terraform...). Git records every change.

| Week | Topic | Folder |
|---|---|---|
| 2 | Git & GitHub, IaC tools comparison | `week02/` |
| 3 | Lab VMs on Proxmox, Ansible inventory, ad-hoc commands | `week03/` |
| 4 | Playbooks: a baseline for every server | `week04/` |
| 5 | Variables, group_vars/host_vars, loops, facts, conditions | `week05/` |
| 6 | Handlers, Jinja2 templates, nginx web servers + HAProxy load balancer | `week06/` |
| 7 | Roles (common, webserver, loadbalancer), collections, Ansible Galaxy | `week07/` |

Each week is tagged `weekNN-done` when it is handed in.

## Lab
| Host | IP | Role |
|---|---|---|
| manager | 10.0.97.37 | Ansible control node |
| worker1 | 10.0.97.38 | web |
| worker2 | 10.0.97.43 | web |
| worker3 | 10.0.97.42 | load balancer (HAProxy :80) + web (nginx :8080) |

Run a week's playbooks from inside its folder (`cd weekNN`), so that its `ansible.cfg` and `inventory.ini` are used.
Collections: `ansible-galaxy collection install -r week07/requirements.yml`.
