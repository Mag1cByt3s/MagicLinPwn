# MagicLinPwn
MagicLinPwn is a powerful and automated Linux privilege escalation script designed to help security professionals and CTF enthusiasts identify potential misconfigurations, vulnerabilities, and weaknesses that can lead to privilege escalation.

## Usage
```bash
./MagicLinPwn.sh
```

<br>

## Features

- **OS Information Gathering**:
  - Detects and displays the operating system, kernel version, architecture, and hostname.
- **User and Group Information**:
  - Displays the current user, UID, GID, primary group, and group memberships with line wrapping and highlighting for critical groups (e.g., `wheel`, `sudo`, `docker`, `lxd`).
- **Sudo Privileges Check**:
  - Checks if `sudo` is installed and if the user can execute `sudo` commands without a password.
  - Highlights critical configurations such as `ALL`, `NOPASSWD`, and `SETENV`.
- **SUID Binary Check**:
  - Finds and lists all binaries with the SUID bit set.
  - Highlights potentially dangerous binaries (e.g., interpreters like `bash` or `python`).
  - Includes a timeout mechanism to skip the check if it takes too long.
- **SGID Binary Check**:
  - Finds and lists all binaries with the SGID bit set.
  - Highlights potentially dangerous binaries (e.g., `mail`, `write`, `wall`).
  - Includes a timeout mechanism to skip the check if it takes too long.

<br>

## Screenshots
![MagicLinPwn_demo](screenshots/demo.png)