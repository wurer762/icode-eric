# Week 2 – Answers

## Q1
In the hidden file `~/.gitconfig` in my home folder (`git config --global --list --show-origin` shows the path).

## Q2
With `pull.rebase false`, `git pull` **merges** the remote changes into my branch: it does a fast-forward if possible, and otherwise creates a merge commit. It does not rebase my local commits on top of the remote ones. That is what happened in Part 9: the pull created the merge commit "Merge GitHub and local README changes". Setting it also removes Git's warning that asks you to choose a pull strategy.

## Q3
- `~/.ssh/id_ed25519.pub` is the **public key**. It gets uploaded to GitHub and can be shared.
- `~/.ssh/id_ed25519` is the **private key**. It must never leave my laptop.

## Q4
A **man-in-the-middle attack** (server spoofing). The fingerprint proves I am talking to the real github.com and not to an attacker who intercepts the connection. After the first connection the key is saved in `~/.ssh/known_hosts`, and SSH warns if it ever changes.

## Q5
`On branch main – Your branch is up to date with 'origin/main'. nothing to commit, working tree clean`.
"Up to date with 'origin/main'" means my local `main` points to the same commit as the copy of GitHub's `main` that my repository knows about (the remote-tracking branch `origin/main`). There is nothing to push or pull. This is only as fresh as the last clone/fetch, though, because Git does not contact GitHub when it runs `git status`.

## Q6
1. Before `add`: **untracked**. The file exists in the working directory, but Git does not track it yet (shown in red under "Untracked files").
2. After `add`: **staged**. The file is in the staging area/index and will go into the next commit (shown in green under "Changes to be committed").
3. After `commit`: **committed**. The file is saved in the repository and the working tree is clean ("nothing to commit"). Before the push, the status also said the branch was ahead of `origin/main` by 1 commit.

## Q7
`git diff` without options compares the **working directory with the staging area**. After `git add README.md` the change is in the staging area, so both are identical and there is no difference. `git diff --staged` compares the staging area with the last commit, and that is why it shows the change.

## Q8
Remove the file from Git and from future commits with `git rm --cached secret.txt` and add it to `.gitignore`, then commit and push. The secret is still in the **history** on GitHub, so:
- treat the secret as compromised and **change/revoke the password or key immediately**. This is the most important step.
- optionally rewrite the history (e.g. `git filter-repo` or BFG) and force-push, so the file disappears from all commits. Everyone who cloned the repo still has the old copy.

## Q9
Yes. `git revert` does not delete anything. It creates a **new commit** that undoes the changes of the old one, so both "Add draft notes for week 2" and "Revert …" are in the history.
Revert is safe after a push because it only **adds** a commit and leaves the shared history alone, so others can simply pull it. `--amend` **replaces** the last commit with a new one (with a new hash). If that commit was already pushed, my history no longer matches GitHub's: I would have to force-push, and that breaks the history for anyone who already pulled the old commit.

## Q10
`main` had no new commits since the branch `add-tools-grid` was created, so Git could just **move the `main` pointer forward** to the branch's latest commit. No merge commit was needed and the history stays a straight line.

## Q11
GitHub's `main` had a commit that my local repository didn't have (the title edit made on GitHub). My local and the remote history had **diverged**, and a push may only add commits on top of the remote branch (fast-forward). Git rejected the push so it wouldn't overwrite the GitHub commit. I first had to `git pull` (fetch + merge) the remote change.

## Q12
Git is a distributed version control system that runs locally and records the history of changes to files in a repository. GitHub is a web service that hosts Git repositories online and adds collaboration features such as access control, a web interface, pull requests and issues.

## Q13
1. **History and traceability**: every change is recorded with author, date and message, so you can see who changed what and why, and compare versions.
2. **Safe undo/rollback**: a broken change can be reverted to a known working version. On a shared drive, overwritten files are simply gone.
3. **Collaboration**: several people can work in parallel on branches, merge their work, resolve conflicts and review changes (pull requests) instead of overwriting each other's files. A remote like GitHub also gives every clone a full backup.

## Q14
- **Agentless: Ansible.** The control node connects to the managed machine over **SSH** (WinRM for Windows), copies small modules there, runs them and removes them, so nothing has to be installed on the target except SSH and Python.
- **Agent-based: Puppet (or Chef).** A Puppet **agent** runs as a service on the managed machine and regularly **pulls** its configuration (catalog) from the Puppet server over HTTPS, then applies it locally.
