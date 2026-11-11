# Week 6 — Answers

## Part A
**Q1.** On the first run SSH restarted **once per host**, even though both tasks can notify `Restart SSH`. On my lab only "Disable X11 forwarding" reported `changed` (`PermitRootLogin no` was already set in week 4), and only a task that reports `changed` sends the notification. The handler ran **at the end of the play**, after all tasks (`RUNNING HANDLER [Restart SSH]`). Even if both tasks had changed, the handler would still run only once. On the second run both tasks were `ok`, nothing notified the handler, and SSH was not restarted (`changed=0`).

## Part B
**Q2.** The `ansible_*` facts such as `ansible_distribution` come from the setup module. A playbook runs it automatically as the first task (`Gathering Facts`). An ad-hoc command only runs the one module you give it, so no facts are gathered and the variable is undefined.

**Q3.** Only two lines differ:
- `<title>` / `<h1>` (`worker1` vs `worker2`): from `inventory_hostname`, the name in the inventory.
- `background: #0094C3` vs `#E94793`: from `page_color`. worker1 gets it from `group_vars/web.yml`, and worker2 overrides it in `host_vars/worker2.yml`, because host_vars beat group_vars.
- The IP line also differs (`10.0.97.26` vs `10.0.97.27`): from the gathered fact `ansible_default_ipv4.address`.

The OS line (`Ubuntu 24.04`, from facts) and the admin list (from `group_vars/all.yml`) are the same on both hosts.

**Q4.** It writes a comma after every name except the last. `loop.last` is true in the last loop iteration, so the inline `if` prints `","` everywhere except there. dave is not listed because the loop has a filter, `if admin.state | default('present') == 'present'`. dave has `state: absent`, so he is skipped. (`loop.last` refers to the filtered list, so carla gets no trailing comma.)

## Part C
**Q5.** nginx was reloaded **once per host**, at the end of the play. Notifications are collected, and each handler runs at most once no matter how many tasks notified it. On the second run nothing changed and there was no reload. `reloaded` is better because nginx re-reads its configuration and starts new worker processes gracefully. The old workers finish their open connections, so no request is dropped. `restarted` stops the whole service (dropping connections) and starts it again. Also, if the new config is broken, a reload keeps the old workers running, while a restart leaves nginx down.

**Q6.** Jinja2 only interprets its own delimiters: `{{ ... }}`, `{% ... %}` and `{# ... #}`. `$uri` is nginx syntax, and for Jinja2 it is just plain text that is copied unchanged.

## Part D
**Q7.**
- `groups['web']` is the list of hosts in the `[web]` group of `inventory.ini` (`worker1`, `worker2`). `groups` is a magic variable built from the inventory.
- `hostvars[host]['ansible_host']` is the `ansible_host=` value of that host in `inventory.ini`. `hostvars` lets the play on worker3 read the variables of *other* hosts.
- `hostvars[host]['web_port']` comes from `group_vars/web.yml` (`web_port: 80`), which applies to each web host (or a host_vars override, see the challenge).

**Q8.** The task "Deploy the HAProxy configuration" **failed** on worker3 with `failed to validate`. HAProxy said: `balance only supports 'roundrobin', 'static-rr', 'leastconn', ...`. The broken file was never installed, the handler did not run, and HAProxy kept running with the old, valid config (`systemctl is-active haproxy` → `active`; `curl` through worker3 still worked). The line that protected me is `validate: haproxy -c -f %s`. Ansible renders the template into a temporary file, runs the check on it, and only replaces `/etc/haproxy/haproxy.cfg` if the check succeeds. Typo fixed afterwards. The next run was all green.

## Part E
**Q9.**
**Prediction:** only "Deploy the start page" on worker2 reports `changed`. worker1 and worker3 report nothing. No handler runs, because that task has no `notify` and nginx serves the new `index.html` straight from disk.

**Actual result:** exactly that. `--check --diff` showed one changed task on worker2, and the diff had only the `background:` line (`#E94793` → `#2E8B57`). The real run gave `worker2 changed=1`, `worker1`/`worker3` `changed=0`, and no `RUNNING HANDLER`. The page through the load balancer now shows the new colour.

## Challenge
- **worker3 as a web server on port 8080:** added `worker3` to `[web]` in `inventory.ini` and created `host_vars/worker3.yml` with `web_port: 8080` and its own `page_color`. The nginx site template and the HAProxy backend loop both use `web_port`, so nothing else had to change. The backend now has three `server` lines (`worker3 10.0.97.28:8080`). Side effect to know about: worker3 is now in both `web` and `lb`. For variables defined in both group files, such as `server_role` and `extra_packages`, the `web` group wins because groups at the same level are merged alphabetically. This would matter for `site.yml`.
- **Statistics page:** a `listen stats` section on `{{ haproxy_stats_port }}` (8404) with `stats enable`, `stats uri /stats` and `stats auth {{ haproxy_stats_user }}:{{ haproxy_stats_password }}`. The variables are in `group_vars/lb.yml`. Without credentials the page returns 401, with them 200. (In a real setup the password belongs in Ansible Vault.)
- **Check play:** `check-lb.yml` runs on the manager, calls `ansible.builtin.uri` four times on the load balancer and extracts the `<h1>`. Output: `worker1, worker2, worker3, worker1`, which is round robin over three servers.

## Review questions
**Q10.**
1. `copy` transfers a file unchanged. `template` first renders it with Jinja2 (variables, facts, loops, conditions), so each host can get a different file.
2. `copy` looks for `src` in `files/` and can also write inline `content:`. `template` looks in `templates/` and is usually used with `.j2` files. Also, only `template` can use `{{ ansible_managed }}` and the host's facts and hostvars.

**Q11.** No. By default, a host that fails stops running the play, and handlers that were notified but not yet run are not run on that host. The config file is then changed, but the service never reloads. Fixes: run with `--force-handlers` (or set `force_handlers: true` in the play / `ansible.cfg`), or put `- ansible.builtin.meta: flush_handlers` before the risky task so pending handlers run right away. Alternatively, fix the error and re-run, but then the file task reports `ok`, so it would not notify again. That is exactly why forcing or flushing is the safer option.

**Q12.** The inventory stays the single source of truth. Adding or removing a web server (as in the challenge) means changing one line in the inventory, and the HAProxy config follows automatically. IPs and ports cannot get out of sync with the real servers, there are no copy-and-paste typos, and the same template works for any environment (lab, test, production) without editing.
