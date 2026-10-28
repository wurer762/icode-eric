# Week 4 – Answers

Run from `~/icode-eric/week04` (uses `ansible.cfg` → `inventory.ini`, copied from week 3).

## Q1
The task **`Gathering Facts`** appears even though I didn't write it. Before the first task Ansible runs the `setup` module on every host in the play (`gather_facts: true` is the default). It connects to each worker and collects facts about it: OS, IPs, CPU, RAM, disks, and so on.
`ansible_distribution` is one of those facts. It isn't defined anywhere in my files. The `setup` module discovered it on each worker (`Ubuntu`, version `24.04`), and then the `debug` task could use it as a variable.

## Q2
```
worker1                    : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
- **ok=3**: 3 tasks ran successfully on worker1 (Gathering Facts, ping, debug).
- **changed=0**: none of them changed anything on the host. ping and debug only read.
- **unreachable=0**: Ansible could connect over SSH every time.
- **failed=0**: no task returned an error.
- **skipped=0**: no task was skipped by a `when:` condition.
- **rescued=0**: no failed task was caught by a `rescue:` block.
- **ignored=0**: no failure was ignored with `ignore_errors: true`.

Tab test: with a tab in front of `ansible.builtin.ping:`, `--syntax-check` stops with
`Syntax Error while loading YAML. found a tab character that violates indentation` and points to line 6 with the hint *"YAML does not use tabs for formatting. Tabs should be replaced with spaces."* It worked again after I replaced the tab with spaces.

## Q3
The VM's **Summary** page now shows the **IP addresses** of the VM, and *"Guest Agent not running"* no longer appears. Proxmox can also use the agent for clean shutdowns and consistent backups (fs-freeze).
The reason is that `qemu-guest-agent` now runs inside each VM. Through a virtual serial channel (virtio-serial) it answers questions from the Proxmox host about the guest (network interfaces, hostname, OS), which the host could not see from outside. The VM option *QEMU Guest Agent* has to be enabled in Proxmox (Options) for this to work.

## Q4
`update_cache: true` alone runs `apt-get update` **every time** the task runs, which is slow and puts load on the mirrors. With `cache_valid_time: 3600`, Ansible first checks how old the package cache is and runs `apt-get update` only if the last update was **more than 3600 s (1 h) ago**. Repeated runs are faster, and the cache update no longer shows up as a change on every run.

## Q5
For the motd task, `--check --diff` shows **`ok`** with no diff, because B2 had already been applied by my earlier draft and `/etc/motd` already had the right content. On a fresh worker it shows a diff: `--- before: /etc/motd` / `+++ after: /etc/motd` with the two new lines marked `+`, and the task reported as **changed**.
The dry run **changed nothing** on the workers. Check mode only predicts what *would* change. The real run afterwards applied the changes.

I also noticed a limitation of check mode: in the dry run the new task `Authorize bob's SSH key` failed with *"Either user must exist or you must provide full path to key file in check mode"*. The previous task only pretended to create bob, so in check mode the user didn't exist yet. The real run worked.

## Q6
The `groups:` list would no longer be added to alice's groups. It would **replace** them. Without `append: true` (the default is `false`), Ansible sets alice's supplementary groups to **exactly** `admins` and removes her from every other group (e.g. `sudo`, `docker`, `adm`) that someone added. Her primary group `alice` stays.

## Q7
Ubuntu reads every file in `/etc/sudoers.d/`. If one of them has a syntax error, `sudo` refuses to work at all (*"parse error … sudo: no valid sudoers sources found"*). That breaks sudo for **everybody**, including the `student` user that Ansible uses with `become`. You can then no longer fix the problem with Ansible (or with sudo), only via the Proxmox console / recovery mode, and that on every server at once.
`validate: /usr/sbin/visudo -cf %s` makes Ansible write the new content to a **temporary file** first and check it with `visudo`. Only if the check passes is the file moved to `/etc/sudoers.d/admins`. With a typo the task fails, and the old (working) file stays untouched.

Test: `ssh -i ~/.ssh/lab/alice alice@10.0.97.26 "sudo whoami"` printed **`root`**.

## Q8
- **Before B5:** `Please login as the user "student" rather than the user "root".` The cloud image's root `authorized_keys` only prints that message, but root login was still allowed in sshd (`#PermitRootLogin prohibit-password`, the default).
- **After B5:** `root@10.0.97.26: Permission denied (publickey).` Now sshd itself rejects root (`PermitRootLogin no`).

Protection: `validate: /usr/sbin/sshd -t -f %s` tests the changed `sshd_config` in a temporary file **before** it replaces the real one. If the line made the config invalid, the task fails, the old config stays, and the following restart never happens. Otherwise sshd could fail to start after the restart, and I'd lock myself (and Ansible) out of the server.

## Q9
The task **`Restart SSH to apply the change`** reports `changed` on every run (`changed=1` on all workers on the 2nd and 3rd runs). `state: restarted` isn't a state that can already be "reached", so the service module restarts sshd every time, whether the config changed or not.
On production that's a problem because:
- every run restarts a service for no reason, which can drop connections and cause small outages (with a web server or database instead of ssh, users notice),
- the playbook is no longer idempotent: `changed` never goes to 0, so you can't use it to detect real drift.

The fix is a **handler** (see Challenge).

## Q10
On the second run of `baseline.sh` on worker3:
- the module reported **CHANGED both times** (it only knows the script ran with rc=0, not what it did),
- `apt-get update` ran again for nothing; apt printed "already the newest version" for every package,
- `groupadd: group 'admins' already exists` (on both runs) and `useradd: user 'carol' already exists` (2nd run) appeared as errors, but the script **didn't stop** and still finished with `Done.` and rc=0, so the errors went unnoticed,
- `/etc/motd` got the line **"This server is managed by a script." twice**, below the Ansible text,
- `/etc/sudoers.d/admins` had the rule **three times** (Ansible's line + one per script run); `>>` appends every time. It's also never checked with visudo, so a typo would have broken sudo,
- sshd was **restarted again**, even though nothing changed.

| | Bash script | Ansible playbook |
|---|---|---|
| **Second run** | Not idempotent: appends duplicate lines (motd, sudoers), shows errors for existing group/user, reruns apt-get update, restarts ssh | Idempotent: checks the state first and changes nothing (`changed=0`, after the handler fix) |
| **Report of what changed** | None. Just a wall of text and one rc; the script module always says CHANGED | Per task and host: ok / changed / failed, plus a PLAY RECAP; `--diff` shows the exact changes |
| **Safety (validate, check mode)** | No dry run, no validation; errors are ignored and the script continues (no `set -e`); a typo in sudoers/sshd_config breaks the server | `--check --diff` dry run, `validate:` for sudoers/sshd_config, stops a host on the first failed task, `--limit` to test on one host |
| **Readability / reuse** | Imperative ("run these commands"), OS specific, hard to adapt; each fix needs extra `if` checks | Declarative ("this is the desired state"), named tasks read like documentation, easy to reuse with variables, roles, other host groups |

## Q11
The playbook describes the **desired state**, not steps. The `copy` tasks for `/etc/motd` and `/etc/sudoers.d/admins` define the **whole content** of each file. Ansible compares the checksum of the file on worker3 with the wanted content, sees that it differs (extra lines from the script), and overwrites the file with the correct content (reported as `changed`). Then the file is exactly as defined: one motd text, one sudoers line. That's how Ansible fixes configuration drift.

## Challenge
Added to `baseline.yml`:
- `ansible.builtin.apt` with `name: telnet` and `state: absent` → telnet removed from all workers (changed on the 1st run, ok afterwards).
- `ansible.builtin.file` with `path: /opt/icode`, `state: directory`, `owner: root`, `group: admins`, `mode: "2775"` → `stat` shows `root:admins 2775 /opt/icode`. The setgid bit (2) makes new files in the folder belong to the `admins` group.
- The SSH restart is now a **handler**: the `lineinfile` task has `notify: Restart SSH`, and the restart lives under `handlers:`. A handler runs only if a notifying task reported `changed`, once at the end of the play.

Result: the 2nd run gives **`ok=14 changed=0`** on all workers. When I set the line back to `#PermitRootLogin prohibit-password` on worker1 by hand, the next run reported the lineinfile task as changed and showed `RUNNING HANDLER [Restart SSH]`, so the restart happens only when it's needed.

## Q12
1. `state:present`: **missing space after the colon**. YAML reads it as the string `"state:present"` instead of the key `state` with value `present`, so the apt module gets an invalid line. Correct: `state: present`.
2. `- name: Start nginx` is **indented more** than `- name: Install nginx`. Both tasks must be at the same level in the `tasks:` list. As written it's a YAML syntax error.
3. **`become: true` is missing**. Installing a package and starting a service need root, so the play fails with permission errors when it runs as `student`.

## Q13
- `--syntax-check` only **parses** the playbook (YAML syntax, known keywords, includes). It doesn't connect to any host and runs nothing.
- `--check` (check mode / dry run) **connects to the hosts**, gathers facts and runs each task in "simulate" mode. It reports what *would* be `changed` without changing anything (add `--diff` to see the file differences). It needs reachable hosts and can fail on tasks that depend on earlier changes (like bob's key in Q5).

## Q14
Use `lineinfile` when you need to change **one line in a file that you don't fully own**, e.g. a config file shipped by the package (`sshd_config`) where the rest should stay at the distribution's defaults and may change with updates.
`copy` (or `template`) is usually more robust because it manages the **whole file**. The result is exactly what's in Git, no matter what was in the file before. With `lineinfile` the end result depends on the existing content: the regexp can match the wrong line, duplicate lines can remain, other manual changes stay, and many `lineinfile` tasks on the same file are hard to read and maintain.

## Q15
Idempotency means a task can run any number of times and always leads to the same end state, changing something only when the system isn't already in that state.
Non-idempotent example: `ansible.builtin.service` with **`state: restarted`** restarts the service on every run (always `changed`). Others: `ansible.builtin.command`/`shell` without `creates:`/`removes:`, or `apt` with `state: latest`, whose result depends on when it runs.
