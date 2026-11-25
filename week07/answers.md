# Week 7 — Answers

> **Lab note:** the workers got new IP addresses (worker1 10.0.97.38, worker2 10.0.97.43, worker3 10.0.97.42), so `inventory.ini` was updated. `carla.pub` did not exist anywhere, so I generated a lab keypair for carla. Only the public key is in `roles/common/files/`; the private key stays on the manager outside Git.

## Part A — The role skeleton

**Q1.** `ansible-galaxy role init` (ansible-core 2.16) created these entries:
- `tasks/` — `main.yml` with the role's task list. This is the entry point that runs when the role is applied.
- `handlers/` — `main.yml` with handlers that the role's tasks can `notify` (e.g. Reload nginx).
- `templates/` — Jinja2 templates (`*.j2`) for the `template` module. They are found by file name alone.
- `files/` — static files for `copy` and for the `file` lookup (e.g. the admins' `*.pub` keys).
- `defaults/` — `main.yml` with default values for the role's variables. These have the **lowest** precedence and are meant to be overridden.
- `vars/` — `main.yml` with internal role variables. These have **high** precedence and are hard to override.
- `meta/` — `main.yml` with Galaxy information (author, licence, platforms, minimum Ansible version) and `dependencies:` on other roles. `argument_specs.yml` can also go here.
- `README.md` — documentation: what the role does, its variables, an example playbook.
- (The 2.16 version also creates a ninth entry, `tests/`, with an inventory and `test.yml` for testing the role.)

## Part B — The common role

**Q2.** At the top, the whole play header is missing: `- name:`, `hosts:`, `become:` and the `tasks:` key. A role's `tasks/main.yml` is only a **list of tasks**. The play that uses the role decides on which hosts it runs and with which privileges. Because the tasks are no longer nested under `tasks:` inside a play, every task starts at column 0 (`- name:`) instead of being indented by 4–6 spaces.

**Q3.** Inside a role, Ansible searches the role's own folders first. `template` looks for `src: motd.j2` in `roles/common/templates/`. The `file` lookup (and `copy`) look for `item.name + '.pub'` in `roles/common/files/`. (If a file isn't there, Ansible also tries the role folder itself and then the playbook directory.) This is why the role is self-contained and can be copied to another project.

**Q4.** worker1 gets **Europe/Luxembourg**. `group_vars/all.yml` has higher precedence than role defaults, which are the weakest variables of all. This is useful because the role always has a working value (`UTC`) when a project sets nothing, while any project can override it in `group_vars/`, `host_vars/` or with `-e` without editing the role. So the same role can be reused unchanged in different environments.

**Q5.** On all three workers `PLAY RECAP: ok=9 changed=3`:
- **Write the message of the day.** `/etc/motd` was still the week 4 text ("This server is managed by Ansible."). The new `motd.j2` adds an `Ansible managed` comment header, host name, IP and server role, so the content differs.
- **Manage admin accounts** and **Authorize SSH keys**, for item `carla` only. carla had never been created on these workers, because her `.pub` key was missing. alice and bob were already there, and dave was already absent.

Packages, time zone, admins group, sudoers (same content as week 4) and `PermitRootLogin no` were already configured, so they reported `ok`. Because the SSH task did not change, `Restart SSH` did not run.

## Part C — Web server and load balancer roles

**Q6.** With `web_port` commented out in `group_vars/web.yml`:
- In the **Web servers** play there is no change. worker1 and worker2 fall back to the role default `80`, and worker3 still has `8080` from `host_vars/worker3.yml`.
- In the **Load balancer** play, worker3 **fails** on "Deploy the HAProxy configuration":
  `AnsibleUndefinedVariable: 'ansible.vars.hostvars.HostVarsVars object' has no attribute 'web_port'` (recap worker3: `failed=1`). The template reads `hostvars[host]['web_port']` for worker1 and worker2. Role defaults are not inventory variables: they only exist while the *webserver* role is running and are not stored in `hostvars`. Inside the `loadbalancer` role there is no `web_port` for worker1 and worker2.

So `web_port` must stay in `group_vars/web.yml`. It is data shared by two roles (nginx listens on it, and HAProxy connects to it), so it has to live in the inventory where every play can see it. I put the line back afterwards.

## Part D — One site.yml for everything

**Q7.** Second run of `ansible-playbook site.yml`:
```
PLAY RECAP *********************************************************************
worker1                    : ok=18   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
worker2                    : ok=18   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
worker3                    : ok=22   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
(Web servers: 2 fact gatherings + 8 common tasks + 8 webserver tasks. The 8 include the argument-spec validation from the challenge. worker3 adds a third fact gathering and 3 loadbalancer tasks.) **changed=0** everywhere. On the first run only the start page changed, because carla is now listed as an admin.
Yes, the load balancer still alternates. Six requests to `http://10.0.97.42/` gave worker1 → worker2 → worker3 → worker1 → worker2 → worker3. It rotates through **all three** members of the `web` group, because worker3 is also in `web` (nginx on port 8080).

**Q8.** **All** pages would change to `#2E9E6A`. The `--check --diff` showed worker1 `#0094C3 → #2E9E6A`, worker2 `#2E8B57 → #2E9E6A` and worker3 `#F5A623 → #2E9E6A`. That includes worker2, even though worker2 has its own `page_color` in `host_vars/worker2.yml` (and worker3 in `host_vars/worker3.yml`). Role `vars/` have a higher precedence than inventory `group_vars` and `host_vars`. Only `set_fact`, `include_vars`, task/block vars and `-e` beat them. So a value in a role's `vars/` folder can't be overridden per host. Use `vars/` only for internal constants the user should never change (e.g. package or service names per OS), and put anything configurable in `defaults/`. Afterwards I reset the file to the empty skeleton from `role init`.

## Part E — Collections and Ansible Galaxy

**Q9.** `ansible-galaxy collection list community.general` shows two copies:
- `/home/student/.ansible/collections/ansible_collections` → **9.5.13** (just installed from Galaxy, the newest version matching `>=9.0.0,<10.0.0`)
- `/usr/lib/python3/dist-packages/ansible_collections` → **8.3.0** (bundled with Ubuntu's `ansible` package)

Ansible uses **9.5.13**. It searches `COLLECTIONS_PATHS` in order, and the user path `~/.ansible/collections` comes before the system path, so the first match wins.
`ansible.posix` installed nothing: `'ansible.posix:1.5.4' is already installed, skipping.` The system copy 1.5.4 already satisfies `>=1.5.0`, so there was nothing to download.

**Q10.** `geerlingguy.ntp` (version 4.0.1):
- Variables I could set: `ntp_timezone` (default `Etc/UTC`), `ntp_servers` (list of pool servers), `ntp_area` (e.g. `europe`), `ntp_enabled`, `ntp_manage_config`, `ntp_restrict`.
- Platforms (from `meta/main.yml`): Fedora, Debian, Ubuntu, FreeBSD, Suse and Archlinux, all versions (there is even a `vars/Ubuntu-24.04.yml`).
- Before trusting a role from the internet I check:
  1. **The code itself.** I read `tasks/`, `handlers/` and `templates/` for anything unexpected (downloads, `shell:` commands, opening ports, changing users or SSH).
  2. **Maintenance and reputation.** I look at the author, the download count, the date of the last release, open issues, the licence, and whether it has tests (`molecule/`, lint config).
  3. **Version pinning and compatibility.** I pin a released version in `requirements.yml` (not the moving `main` branch), and check that `min_ansible_version` and the supported platforms match my servers. Then I test it with `--check --diff` on a test host first.

## Challenge
- **Tags:** `site.yml` has `tags: base`, `web` and `lb` on the three plays. `ansible-playbook site.yml --list-tags` shows `[base]`, `[always, web]` (the argument-spec validation task is tagged `always`) and `[lb]`. `ansible-playbook site.yml --tags web` runs only the web server play.
- **`dependencies: [common]` in `roles/webserver/meta/main.yml`:** Ansible removes duplicate roles only *within one play*. `common` would run once in play 1 (Baseline) and again in play 2 as a dependency of `webserver`. So it runs **twice on worker1** (and worker2 and worker3). The second run is all `ok`, so it does no harm, but it doubles the run time and hides the structure. Since `site.yml` already applies `common` to every worker, the dependency is not a good idea here. It only makes sense when `webserver` is used on its own in other projects. I did not keep it.
- **`roles/webserver/meta/argument_specs.yml`:** declares `web_port` as `type: int, required: true` and `page_color` as `str`. Tested with `-e web_port=abc`:
  `Validation of arguments failed: argument 'web_port' is of type <class 'str'> and we were unable to convert to int`.
  The role stops before it touches nginx.

## Review questions

**Q11.** A playbook is the file you run. It maps groups of hosts to the work they get, through plays. A role is a reusable package of that work (tasks, handlers, templates, files and default variables in a fixed folder structure) that has no hosts of its own and is applied by any playbook that lists it.

**Q12.**
- `defaults/main.yml`: values the user of the role is *expected* to change, with a sensible fallback (ports, colours, package lists). They have the lowest precedence.
- `vars/main.yml`: role-internal constants that should *not* be overridden from the inventory (e.g. OS-specific package or service names). They have high precedence.
- `group_vars/` (or `host_vars/`): the values of *this* project and environment, especially data shared between roles (e.g. `web_port`, read by webserver and loadbalancer), and per-group or per-host differences.

**Q13.** A **role** is one unit of configuration work (tasks, handlers, templates, defaults) for one job. A **collection** is a distribution package with a namespace that can bundle modules, plugins, filters *and* roles, and it is installed and versioned as a whole.
- Collection I used: `community.general` (module `community.general.timezone`), also `ansible.posix` (`authorized_key`).
- Role I used: my own `common`, `webserver`, `loadbalancer`, and `geerlingguy.ntp` from Galaxy (downloaded only).

**Q14.** It makes the project reproducible. Anyone who clones the repository (a colleague, CI, me on a new manager) runs `ansible-galaxy collection install -r requirements.yml` and gets the same dependencies within the tested version range, instead of whatever their distro bundles (here 8.3.0 vs 9.5.13). Upper bounds such as `<10.0.0` protect against breaking changes in new major versions. Changes to the dependencies are reviewed and tracked in Git history like any other code.
