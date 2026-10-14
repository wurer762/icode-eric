# Week 3 – Answers

## Lab parameters

| Parameter | Value |
|---|---|
| My student number NN | **TODO** |
| Template VM ID (NN99) | **TODO** |
| manager VM ID / IP | **TODO** / 10.0.97.16 |
| worker1 · worker2 · worker3 VM IDs | **TODO** |
| worker1 · worker2 · worker3 IPs | 10.0.97.26 · 10.0.97.27 · 10.0.97.28 |
| Prefix length / gateway / DNS | /16 · 10.0.0.1 · 10.0.0.62, 10.0.0.1 |
| Storage ID · bridge (Part 0) | **TODO** · **TODO** |

## Q1
Storage ID: **TODO**, bridge: **TODO** (look up in Proxmox: Datacenter → Storage, and node → System → Network).

- A **Proxmox storage** is a configured place (local disk, LVM-thin pool, NFS share, …) where Proxmox keeps VM disks, ISO images, templates or backups; each storage has an ID and allowed content types such as "Disk image".
- A **Linux bridge** (e.g. `vmbr0`) is a virtual network switch on the Proxmox host that connects the VMs' virtual network cards to the physical network card and thus to the school network.

## Q2
- `import-from=…noble-server-cloudimg-amd64.img` – creates a new VM disk on the storage and copies (imports) the Ubuntu cloud image into it, so the VM boots from a ready-installed Ubuntu instead of an installer ISO.
- `--ide2 local-lvm:cloudinit` – adds a small virtual CD-ROM drive that holds the cloud-init data (user, password, SSH keys, IP config) which Proxmox generates from the Cloud-Init tab; the VM reads it on first boot.
- `--boot order=scsi0` – tells the VM to boot only from the imported disk `scsi0` (not from the network or the cloud-init drive).
- `qm template` – converts the VM into a read-only template; it can't be started anymore, but it can be cloned many times.

## Q3
The VM's hostname is `icode-eric-m` (workers: `icode-eric-w-1/2/3`). It comes from cloud-init: Proxmox passes the VM name as the hostname in the cloud-init data, and cloud-init sets it on first boot (`/var/lib/cloud/instance/user-data.txt` contains `hostname: icode-eric-m`).
`sudo whoami` works without a password because cloud-init created the user `student` with the rule `student ALL=(ALL) NOPASSWD:ALL` in `/etc/sudoers.d/`, so this user can use sudo without typing a password.

## Q4
An automation key is used by programs (Ansible, scripts, cron jobs) that run without a person present, so nobody could type a passphrase – that's why it has none. The risk: the private key file itself is the only protection. Anyone who gets a copy of `~/.ssh/id_ed25519` (e.g. a hacked manager, a backup, or accidentally committing it to Git) can immediately log in to all workers – and because `student` has passwordless sudo, become root on them.

## Q5
- Typing errors: wrong IP or gateway, duplicate IP or VM ID, wrong storage/bridge name → VM not reachable or clashes with another student's VM.
- Forgetting a step: e.g. not pasting the manager key into a worker, forgetting "Regenerate Image", or using a Linked Clone instead of Full Clone → Ansible can't connect or VMs depend on the template.
- Inconsistency and no record: every server ends up slightly different (RAM, disk size, settings), it takes a lot of time, and nobody can repeat exactly what was done – for 50 servers this is slow and error-prone.

## Q6
Ansible **core 2.16.3** was installed (Ubuntu 24.04 package).
The line says `config file = /home/student/icode-eric/week03/ansible.cfg` when run from the week03 folder, because Ansible looks for `ansible.cfg` in the current directory first (before `~/.ansible.cfg` and `/etc/ansible/ansible.cfg`). Outside the project folder it shows `config file = None`, because the Ubuntu package ships no `/etc/ansible/ansible.cfg`.

## Q7
The manager doesn't use SSH to reach itself. In the inventory it has `ansible_connection=local`, so Ansible runs the module directly on the local machine as the current user (`ESTABLISH LOCAL CONNECTION FOR USER: student` in `-vvv` output). No SSH login happens, so no key in `authorized_keys` is needed.

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
