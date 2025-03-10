# MagicLinPwn
MagicLinPwn is a powerful and automated Linux privilege escalation script designed to help security professionals and CTF enthusiasts identify potential misconfigurations, vulnerabilities, and weaknesses that can lead to privilege escalation.

Once the script finishes, a comprehensive summary is displayed, providing an overview of the findings and highlighting potential risks.

<br>

## Usage
```bash
./MagicLinPwn.sh
```

<br>

## Features

- **OS Information Gathering**:
  - Detects and displays the operating system, kernel version, architecture, and hostname.
- **Kernel Exploit Suggestion**:
  - Integrates Linux Exploit Suggester to identify potential kernel         vulnerabilities for privilege escalation.
  - Cross-references the system's kernel version against known exploits.
  - Highlights kernel vulnerabilities that may be exploitable for privilege escalation.
  - Provides direct links to resources for further analysis and exploitation.
  - Displays results in the summary section, flagging any discovered kernel-level privilege escalation vectors.
- **User and Group Information**:
  - Displays the current user, UID, GID, primary group, and group memberships with line wrapping.
  - Highlights critical groups that may allow privilege escalation (e.g., `wheel`, `sudo`, `docker`, `lxd`, `shadow`, etc.).
  - Provides explanations for highlighted groups, including how they can be abused for privilege escalation.
  - Where applicable, includes direct links to **HackTricks** for detailed exploitation techniques.
- **Root Privilege Check**:
  - Detects if the script is running with root privileges (via `UID` or `EUID`).
    - If running as root, suggests using additional tools for credential dumping:
      - [mimipenguin](https://github.com/huntergregal/mimipenguin)
      - [LaZagne.py](https://github.com/AlessandroZ/LaZagne)
- **Active Directory Integration Check**:
  - Detects if the Linux machine is joined to an Active Directory domain.
  - Displays relevant domain information if detected.
  - If running as root and AD integration is found, suggests using [Linikatz](https://github.com/Orange-Cyberdefense/LinikatzV2) for dumping secrets.
- **Docker Container Detection**:
  - Detects if the script is running inside a Docker container by checking:
      - `/proc/1/cgroup`
      - The existence of the `/.dockerenv` file
      - Environment variables (e.g., `DOCKER_CONTAINER`)
  - Suggests running `deepce` for container breakout checks if a container is detected.
- **Sudo Privileges Check**:
  - Checks if `sudo` is installed, displays the sudo version and if the user can execute `sudo` commands without a password.
  - Highlights critical configurations such as `ALL`, `NOPASSWD`, and `SETENV`.
- **Network Interfaces and Listening Ports**:
  - Displays all active network interfaces with assigned IP addresses.
  - Lists open listening ports along with their associated processes.
  - Uses `ss` (or `netstat` as a fallback) to detect services that may be exploited.
- **Environment Variable Check**:
  - Scans environment variables for potential sensitive information such as `PASSWORD`, `TOKEN`, `SECRET`, `DB` etc.
  - Highlights detected variables for further investigation.
  - Provides a clear message if no sensitive information is found.
- **SUID Binary Check**:
  - Finds and lists all binaries with the SUID bit set.
  - Highlights potentially dangerous binaries (e.g., interpreters like `bash` or `python`).
  - Includes a timeout mechanism to skip the check if it takes too long.
- **SGID Binary Check**:
  - Finds and lists all binaries with the SGID bit set.
  - Highlights potentially dangerous binaries (e.g., `mail`, `write`, `wall`).
  - Includes a timeout mechanism to skip the check if it takes too long.
- **Cron Job Analysis**:
  - **System-Wide Cron Jobs**: Lists cron jobs from `/etc/cron.d` and their contents.
  - **User-Specific Cron Jobs**: Checks the current user’s crontab for entries.
  - **/etc/crontab Analysis**: Displays the contents of `/etc/crontab` and checks if it is writable.
  - **Writable Cron Files**: Identifies writable cron files across `/etc/cron*` directories and highlights potential security risks.
- **Capabilities Check**:
  - Finds and lists all files with Linux capabilities.
  - Highlights potentially dangerous capabilities (e.g., `cap_setuid`, `cap_net_raw`, `cap_dac_override`).
  - Includes a timeout mechanism to skip the check if it takes too long.
- **Writable Critical Files and Directories Check**:
  - Checks critical system files (e.g., `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`) for write permissions.
  - Checks critical directories (e.g., `/etc/sudoers.d`, `/etc/cron.d`) for write permissions and scans for writable files within them.
  - Highlights writable files and directories as potential security risks.
  - Provides clear summary messages when no writable files or directories are detected.
- **Potentially Interesting Files Search**:
  - Searches for files with potentially sensitive extensions (e.g., `.xls`, `.doc`, `.pdf`, `.conf`, `.key`).
  - Excludes common irrelevant directories like `lib`, `fonts`, `share`, and `core`.
  - Displays results clearly for each file extension.
  - Handles cases where no files are found with a clean message.
- **Email Enumeration**:
  - Searches for readable mailboxes in `/var/mail/` and prints their **full content**.
  - Displays email metadata (sender, recipient, date) and message body.
  - Highlights any discovered emails that may contain **sensitive information**.
  - If no readable mailboxes are found, it provides a clear message.
- **Sensitive Content Search**:
  - Searches `.cnf`, `.conf`, and `.config` files for sensitive keywords like `password` or `pass`.
  - Excludes unnecessary directories (e.g., `doc`, `lib`) to reduce noise.
  - Highlights matches for better readability.
  - Only displays filenames and content when matches are found.
- **SSH Private Key Search**:
  - Searches common directories like `/root`, `/home`, and `/etc/ssh` for files containing ssh private keys.
  - Highlights private keys in the results for better visibility.
  - Filters out irrelevant matches, ensuring only valid keys are displayed.
  - Provides a clear message if no private keys are found.
- **Shell History File Dump**:
  - Searches for commonly used shell history files (e.g., `.bash_history`, `.zsh_history`, `.ash_history`, etc.) in `/home` and `/root` directories.
  - Dumps the contents of any accessible history files for analysis.
  - Highlights the file paths and their contents, providing insights into commands executed by users.
  - Clearly indicates if no history files are found or accessible.
- **Credential Discovery in Log Files**:
  - Searches common log files (`auth.log`, `access.log`, `syslog`, etc.) for potential credentials.
  - Identifies sensitive information such as usernames, passwords, API tokens, and secrets.
  - Highlights findings and provides a summary indicating whether credentials were discovered.
- **Systemd-Related Privilege Escalation Checks**:
  - Identifies writable `.service` files in common systemd directories (e.g., `/etc/systemd/system`, `/lib/systemd/system`).
  - Detects writable binaries executed by services via the `ExecStart=` directive in `.service` files.
  - Searches for writable folders in systemd `UnitPath`, which could allow malicious file placements.
  - Checks for writable `.timer` files, which could be exploited to schedule malicious tasks.
  - Includes timeout mechanisms to ensure efficient scans and prevent prolonged execution.
  - Highlights writable files, binaries, directories, and timers as potential security risks.
- **Writable Files and Directories Check**:
  - Searches for files and directories writable by the current user.
  - Excludes system-critical paths like `/proc`, `/sys`, `/tmp`, and `/run` to avoid unnecessary output.
  - Displays both writable files and writable directories separately.
  - Includes a timeout mechanism to prevent the scan from running indefinitely.
  - Clearly indicates if no writable files or directories are found.
- **Brief Summary at the End**:
    Provides a summary of all findings from the script.
    Highlights areas that require attention (e.g., writable files, dangerous capabilities, sensitive environment variables).
    Displays reassuring messages when no issues are found in specific checks.
    Ensures users have a quick overview of potential privilege escalation vectors without scrolling through the detailed output.

<br>

## Screenshots
![MagicLinPwn_demo](screenshots/demo.png)
