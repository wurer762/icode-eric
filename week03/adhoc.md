# Week 3 – Ad-hoc commands

Run from `~/icode-eric/week03` (uses `ansible.cfg` → `inventory.ini`).

## G1 · Normal user or root?

| Command | What it did |
|---|---|
| `ansible workers -a "whoami"` | Ran `whoami` on all 3 workers; each printed `student` (yellow CHANGED, because the command module always reports a change). |
| `ansible workers -a "whoami" --become` | Same command but via sudo; each worker printed `root`. |

## G2 · Facts

| Command | What it did |
|---|---|
| `ansible worker1 -m setup \| less` | Collected all ~860 lines of facts about worker1 (hostname `icode-eric-w-1`, 2 vCPUs, 1967 MB RAM, kernel 6.8.0-142, kvm, …). |
| `ansible workers -m setup -a "filter=ansible_distribution*"` | Showed only the distribution facts: all workers run Ubuntu 24.04 (noble), green SUCCESS. |
| `ansible workers -m setup -a "filter=ansible_default_ipv4"` | Showed the default network interface: `eth0`, addresses 10.0.97.26/.27/.28, gateway 10.0.0.1. |

## G3 · Install a package — twice

| Command | What it did |
|---|---|
| `ansible workers -m apt -a "name=htop state=present update_cache=true"` | Red FAILED: as `student`, apt cannot lock `/var/lib/apt/lists/lock` (Permission denied). |
| `ansible workers -m apt -a "name=htop state=present update_cache=true" --become` | With sudo it worked. **Note:** in my lab htop was already installed on the Ubuntu image, so this showed green SUCCESS (`changed: false`) instead of CHANGED. |
| `ansible workers -m apt -a "name=htop state=present" --become` | Green SUCCESS – htop already present, nothing to do. |

Extra run after G5 had removed htop, to see the expected behaviour:

| Command | Result |
|---|---|
| `ansible workers -m apt -a "name=htop state=present update_cache=true" --become` | Yellow CHANGED – htop was installed. |
| `ansible workers -m apt -a "name=htop state=present" --become` | Green SUCCESS – already installed, no change. |
| `ansible workers -m apt -a "name=htop state=absent" --become` (twice) | First CHANGED (removed), second SUCCESS (already absent). |

## G4 · Compare with the command module

| Command | What it did |
|---|---|
| `ansible workers -a "apt-get install -y htop" --become` | Yellow CHANGED on every run, even though apt printed "htop is already the newest version". |

## G5 · Files and state=absent

| Command | What it did |
|---|---|
| `echo "Managed by Ansible" > hello.txt` | Created a local file on the manager. |
| `ansible workers -m copy -a "src=hello.txt dest=/tmp/hello.txt"` | First run: CHANGED – the file was copied to all workers. |
| `ansible workers -m copy -a "src=hello.txt dest=/tmp/hello.txt"` | Second run: SUCCESS – the checksum matched, so nothing was copied. |
| `ansible workers -a "cat /tmp/hello.txt"` | Printed `Managed by Ansible` on each worker. |
| `ansible workers -m apt -a "name=htop state=absent" --become` | CHANGED – htop was uninstalled from all workers. |

## Challenge – YAML inventory

| Command | What it did |
|---|---|
| `ansible-inventory -i inventory.yml --graph --vars` | Showed the same groups/hosts as `inventory.ini` (managers: manager; workers: worker1–3), plus `ansible_user = student` on all. |
| `ansible all -i inventory.yml -m ping` | All 4 hosts answered `pong` (SUCCESS). |
