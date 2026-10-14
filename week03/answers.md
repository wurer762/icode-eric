# Week 3 – Answers

> Answers to earlier questions (Q1–Q7) still to be added.

## Q8
Without `--become`, `whoami` prints `student` (the SSH user from `ansible.cfg`). With `--become` it prints `root`: Ansible ran the command through `sudo`, so it executed with root privileges.

## Q9
Useful facts, for example:
- `ansible_distribution` / `ansible_distribution_version` (Ubuntu 24.04) – choose `apt` vs `dnf`, or package names per OS version.
- `ansible_memtotal_mb` / `ansible_processor_vcpus` (1967 MB, 2 vCPUs) – size a service, e.g. number of worker processes or JVM heap.
- `ansible_default_ipv4.address` / `.interface` (10.0.97.26, eth0) – write the right IP into a config file or firewall rule.

(Also handy: `ansible_hostname`, `ansible_architecture`, `ansible_virtualization_type`.)

## Q10
1. **Fails:** without `--become` the command runs as `student`, and installing packages / locking `/var/lib/apt/lists/lock` needs root → Permission denied.
2. **CHANGED:** with `--become` it runs as root; htop was not installed, so apt installed it – the system state changed.
3. **SUCCESS:** htop is already present, so the apt module checks the state, sees it already matches `state=present`, and does nothing.

The third one shows **idempotency**: running the same task again gives the same result without changing anything.

(In my lab htop was preinstalled on the image, so command 2 also showed SUCCESS; after removing htop in G5 and re-running I got the expected CHANGED → SUCCESS.)

## Q11
The `command` module just runs a shell command; it doesn't know what `apt-get` does or what the desired state is. Ansible can only see that the command ran (rc=0), so it always assumes something changed. The `apt` module, in contrast, checks the package state first and only reports CHANGED if it actually did something.

## Q12
No, `hello.txt` should not be committed – it is just a temporary test file for the copy module and not part of the lab's configuration. It's harmless because it only contains "Managed by Ansible", no secrets. What must **never** be committed are secrets: private SSH keys (`id_ed25519`, `*.pem`), passwords, vault password files, API tokens. These are already blocked by `.gitignore`.

## Q13
```
                         +-----------------------------+
                         |           GitHub            |
                         |  (repo wurer762/icode-eric) |
                         +-----------------------------+
                            ^                       ^
          git push over SSH |                       | git push over SSH
   key: manager ~/.ssh/     |                       | key: laptop's own SSH key
        id_ed25519          |                       |
                            |                       |
+---------------------------|-----------------------|-------------+
| Proxmox host              |                       |             |
|                  +-----------------+              |             |
|                  |    manager      |              |             |
|                  |   10.0.97.16    |              |             |
|                  | Ansible control |              |             |
|                  +-----------------+              |             |
|                  /        |        \              |             |
|   SSH key: manager ~/.ssh/id_ed25519 (user student)              |
|                /          |          \            |             |
|               v           v           v           |             |
|      +-----------+ +-----------+ +-----------+    |             |
|      |  worker1  | |  worker2  | |  worker3  |    |             |
|      |10.0.97.26 | |10.0.97.27 | |10.0.97.28 |    |             |
|      +-----------+ +-----------+ +-----------+    |             |
+------------------------------^--------------------|-------------+
                               |                    |
          SSH to manager       |                    |
          key: laptop's own    |                    |
          SSH key              |                    |
                         +-----------+              |
                         |  Laptop   |--------------+
                         +-----------+
               (also: browser -> Proxmox web UI over HTTPS, no SSH key)
```
- Laptop → manager: SSH with the laptop's key (its public key is in the manager's `authorized_keys`).
- Manager → workers: SSH with `~/.ssh/id_ed25519` (its public key is in each worker's `authorized_keys`).
- Manager → GitHub: SSH with `~/.ssh/id_ed25519` (public key added to the GitHub account).

## Q14
"Agentless" means no Ansible software/daemon has to be installed on the node. A managed Linux node only needs:
- a running **SSH server** reachable from the control node, with a user Ansible can log in as (here `student` with our public key in `authorized_keys`),
- **Python 3** (the modules are copied over and executed with it),
- **sudo** rights for that user if tasks use `--become`.

## Q15
```
ansible workers --list-hosts
```
(or `ansible-inventory --graph workers`). It only reads the inventory and doesn't connect to the hosts.

## Q16
Idempotency means running the same task many times gives the same end state, and it only changes something when the system isn't already in the desired state. With htop: the first `apt name=htop state=present` installed it (CHANGED), every later run saw it was already there and did nothing (SUCCESS).

On 200 servers every night this matters because:
- it's safe to re-run: nothing is reinstalled, restarted or broken on servers that are already correct,
- the run is faster and causes no unnecessary downtime,
- the CHANGED count becomes a useful signal: if a server reports CHANGED, something had drifted (someone changed it by hand) and Ansible fixed it – so you can detect and repair configuration drift automatically.
