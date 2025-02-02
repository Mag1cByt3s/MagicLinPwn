#!/usr/bin/env bash

# Function to print ASCII art
ascii_art() {
    # Set the purple color for the ASCII art
    echo -e "\e[1;35m"
cat << "EOF"
  __  __             _      _     _       ____                 
 |  \/  | __ _  __ _(_) ___| |   (_)_ __ |  _ \__      ___ __  
 | |\/| |/ _` |/ _` | |/ __| |   | | '_ \| |_) \ \ /\ / / '_ \ 
 | |  | | (_| | (_| | | (__| |___| | | | |  __/ \ V  V /| | | |
 |_|  |_|\__,_|\__, |_|\___|_____|_|_| |_|_|     \_/\_/ |_| |_|
               |___/                                           
                                                                 
EOF
    # Reset the color for the script title
    echo -e "\e[0m"
    echo -e "             Linux Privilege Escalation Script"

    # Add the colored author and GitHub link
    echo -e "                    By \e[1;35m@Mag1cByt3s\e[0m"
    echo -e "        (https://github.com/Mag1cByt3s/MagicLinPwn)"
}

# Set Up Summary Variables
os_info_summary=""
user_info_summary=""
sudo_priv_summary="No unusual sudo privileges detected."
suid_summary="No SUID binaries detected."
sgid_summary="No SGID binaries detected."
cron_summary="No writable cron jobs or misconfigurations detected."
capabilities_summary="No dangerous file capabilities detected."
writable_files_summary="No writable critical files or directories detected."
interesting_files_summary="No interesting files detected."
ssh_keys_summary="No SSH private keys found."
docker_summary="Not running in a Docker container."
env_vars_summary="No sensitive environment variables detected."
systemd_summary="No writable systemd files or misconfigurations detected."

# Function to detect if running inside a Docker container
detect_docker_container() {
    docker_detected=0

    # Check for /.dockerenv file
    if [ -f /.dockerenv ]; then
        echo -e "\e[1;33m[!] Detected: /.dockerenv file exists (Docker container environment)\e[0m"
        docker_detected=1
    fi

    # Check for 'docker' in cgroup
    if grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo -e "\e[1;33m[!] Detected: 'docker' found in /proc/1/cgroup (Docker container environment)\e[0m"
        docker_detected=1
    fi

    # Check for 'containerd' in cgroup (alternative to detect container runtimes)
    if grep -q containerd /proc/1/cgroup 2>/dev/null; then
        echo -e "\e[1;33m[!] Detected: 'containerd' found in /proc/1/cgroup (Docker container environment)\e[0m"
        docker_detected=1
    fi

    # Check for any environment variable indicating Docker
    if [ -n "$DOCKER_CONTAINER" ]; then
        echo -e "\e[1;33m[!] Detected: DOCKER_CONTAINER environment variable set\e[0m"
        docker_detected=1
    fi

    # Suggest deepce if inside a container
    if [ $docker_detected -eq 1 ]; then
        echo -e "\n\e[1;36m[+] Suggestion: Consider running \e[1;34mdeepce\e[0m (\e[4mhttps://github.com/stealthcopter/deepce\e[0m) to investigate container breakout potential.\e[0m"

        # docker container was detected. Add to summary
        docker_summary="Running inside a Docker container."
    fi
}

check_if_root() {
    if [ "$(id -u)" -eq 0 ] || [ "$(id -ru)" -eq 0 ]; then
        # If root, check if inside a Docker container
        detect_docker_container

        echo -e "\n\e[1;36m[+] Suggestion: As root, consider using the following tools for credential dumping:\e[0m"
        echo -e "    \e[1;34m- mimipenguin\e[0m (\e[4mhttps://github.com/huntergregal/mimipenguin\e[0m)"
        echo -e "    \e[1;34m- LaZagne.py\e[0m (\e[4mhttps://github.com/AlessandroZ/LaZagne\e[0m)"

        # If not inside a container, display a simple root message and exit
        if [ "$docker_detected" -eq 0 ]; then
            echo -e "\e[1;31m[-] You are already running as root (UID or EUID). Exiting...\e[0m"
        fi

        # Exit script since privilege escalation is unnecessary as root
        exit 0
    fi
}

# Function to highlight specific groups and provide abuse information
highlight_groups() {
    local group=$1
    case "$group" in
        wheel)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Wheel Group:\e[0m Allows users to execute commands as root via sudo."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#wheel-group"
            ;;
        docker)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Docker Group:\e[0m Can run Docker containers as root, leading to privilege escalation."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#docker-group"
            ;;
        lxd)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] LXD Group:\e[0m Can create privileged containers, leading to root access."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/lxd-privilege-escalation.html"
            ;;
        sudo)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Sudo Group:\e[0m Allows running commands as root if misconfigured."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#sudoadmin-groups"
            ;;
        libvirt)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Libvirt Group:\e[0m Can control virtual machines, possibly leading to privilege escalation."
            echo -e "    \e[1;36m[-> Medium]:\e[0m https://medium.com/@alinuxadmin/arbitrary-file-read-write-and-rce-using-libvirt-ebc239dcbd8d"
            ;;
        kvm)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] KVM Group:\e[0m Has access to virtual machine control, potential escalation risk."
            ;;
        disk)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Disk Group:\e[0m Allows direct disk access, enabling password or file extraction."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#disk-group"
            ;;
        www-data|apache|nginx)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Web Server Group:\e[0m Common for web service users, may lead to web-based privilege escalation."
            ;;
        shadow)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Shadow Group:\e[0m Can read /etc/shadow, enabling password hash extraction."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#shadow-group"
            ;;
        root)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Root Group:\e[0m Full system control. Check if it is misconfigured."
            ;;
        staff)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Staff Group:\e[0m Allows users to add local modifications to the system (/usr/local) without needing root privileges (note that executables in /usr/local/bin are in the PATH variable of any user, and they may "override" the executables in /bin and /usr/bin with the same name)."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#staff-group"
            ;;
        adm)
            echo -e "\e[1;31m$group\e[0m"
            echo -e "    \e[1;33m[!] Admin Group:\e[0m Can read logs, useful for privilege escalation via credential leaks."
            echo -e "    \e[1;36m[-> HackTricks]:\e[0m https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/interesting-groups-linux-pe/index.html#adm-group"
            ;;
        *)
            echo "$group"  # Default color for other groups
            ;;
    esac
}


# Function to display OS information
os_info() {
    echo -e "\n\n\e[1;34m[+] Gathering OS Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    kernel_version=$(uname -r)
    architecture=$(uname -m)
    hostname=$(hostname)
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        distro_name="$NAME"
        distro_version="$VERSION"
    else
        distro_name="Unknown"
        distro_version="Unknown"
    fi

    echo -e "\e[1;33mKernel Version:\e[0m $kernel_version"
    echo -e "\e[1;33mDistro Name:\e[0m $distro_name"
    echo -e "\e[1;33mDistro Version:\e[0m $distro_version"
    echo -e "\e[1;33mArchitecture:\e[0m $architecture"
    echo -e "\e[1;33mHostname:\e[0m $hostname"

    os_info_summary="Kernel: $kernel_version, Distro: $distro_name $distro_version, Arch: $architecture, Hostname: $hostname"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to check if the machine is domain joined
check_ad_integration() {
    echo -e "\n\n\e[1;34m[+] Checking for Active Directory Integration\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Check if machine is domain joined using realm
    if command -v realm >/dev/null 2>&1; then
        realm_list=$(realm list 2>/dev/null)
        if echo "$realm_list" | grep -q "configured: kerberos-member"; then
            echo -e "\e[1;33m[!] This machine is domain-joined (Active Directory detected):\e[0m"
            echo "$realm_list" | sed 's/^/    /'

            # Suggest using Linikatz if root
            if [ "$(id -u)" -eq 0 ]; then
                echo -e "\n\e[1;36m[+] Suggestion: As root, use \e[1;34mLinikatz\e[0m to dump secrets from Active Directory:\e[0m"
                echo -e "    \e[4mhttps://github.com/Orange-Cyberdefense/LinikatzV2\e[0m"
            fi
        else
            echo -e "\e[1;32m[+] No Active Directory integration detected.\e[0m"
        fi
    else
        echo -e "\e[1;31m[-] 'realm' command not found. Unable to check for AD integration.\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display current user and group memberships
user_info() {
    echo -e "\n\n\e[1;34m[+] Gathering User Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    
    # Display the current user
    current_user=$(whoami)
    echo -e "\e[1;33mCurrent User:\e[0m $current_user"
    
    # Display the current user's UID and GID
    uid=$(id -u)
    gid=$(id -g)
    echo -e "\e[1;33mUser ID (UID):\e[0m $uid"
    echo -e "\e[1;33mGroup ID (GID):\e[0m $gid"
    
    # Display the user's primary group
    primary_group=$(id -gn)
    echo -e "\e[1;33mPrimary Group:\e[0m $primary_group"
    
    # Display all groups with wrapping
    echo -ne "\e[1;33mGroup Memberships:\e[0m "
    group_memberships=$(id -Gn | tr ' ' '\n' | while read group; do
        # Highlight specific groups
        highlighted_group=$(highlight_groups "$group")
        echo -n "$highlighted_group, "
    done | sed 's/, $//' | fold -s -w 50 | sed '1!s/^/             /')
    echo -e "$group_memberships"

    # Update summary
    user_info_summary="User: $current_user (UID: $uid, GID: $gid), Primary Group: $primary_group, Groups: $(echo "$group_memberships" | tr '\n' ' ')"
    
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to check and highlight sudo permissions
sudo_check() {
    echo -e "\n\n\e[1;34m[+] Checking Sudo Privileges\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary variable
    sudo_priv_summary="No unusual sudo privileges detected."

    # Check if sudo is installed
    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "\e[1;31m[-] Sudo is not installed on this system.\e[0m"
        sudo_priv_summary="Sudo is not installed."
        echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
        return
    fi

    # Get and display sudo version number
    sudo_version=$(sudo --version | head -n 1 | awk '{print $3}')
    echo -e "\e[1;33m[!] Sudo Version:\e[0m $sudo_version"

    # Check if the user can run `sudo -l` without a password
    sudo_output=$(sudo -n -l 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "\e[1;33m[!] User can run the following \e[1;31msudo\e[0m \e[1;33mcommands without a password:\e[0m"

        # Update the summary
        sudo_priv_summary="User has sudo privileges without a password. Review required."

        # Process the output line by line and highlight critical elements
        while IFS= read -r line; do
            # Highlight critical elements using printf with proper ANSI codes
            line=$(echo "$line" | sed \
                -e 's/ALL/\x1b[1;31mALL\x1b[0m/g' \
                -e 's/NOPASSWD/\x1b[1;31mNOPASSWD\x1b[0m/g' \
                -e 's/SETENV/\x1b[1;33mSETENV\x1b[0m/g' \
                -e 's/env_keep/\x1b[1;31menv_keep\x1b[0m/g' \
                -e 's/passwd_timeout=0/\x1b[1;35mpasswd_timeout=0\x1b[0m/g')
            
            # Print the highlighted line with proper indentation
            printf "    %b\n" "$line"
        done <<< "$sudo_output"
    else
        echo -e "\e[1;31m[-] User cannot run sudo commands without a password.\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Check environment variables for sensitive information
check_env_variables() {
    echo -e "\n\n\e[1;34m[+] Checking Environment Variables for Sensitive Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Define patterns to look for
    sensitive_patterns=("PASS" "PASSWORD" "TOKEN" "SECRET" "KEY" "AWS" "API" "DB" "CREDENTIAL" "CRED" "SQL")

    # Initialize the summary variable
    env_vars_summary="No sensitive information detected in environment variables."

    # Iterate through environment variables
    found_sensitive=0
    for var in $(env); do
        for pattern in "${sensitive_patterns[@]}"; do
            if echo "$var" | grep -qi "$pattern"; then
                echo -e "\e[1;33m[!] Potential Sensitive Information:\e[0m $var"
                found_sensitive=1
            fi
        done
    done

    if [ $found_sensitive -eq 0 ]; then
        echo -e "\e[1;32m[+] No sensitive information detected in environment variables.\e[0m"
    else
        env_vars_summary="Sensitive environment variables detected. Review needed."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check SUID binaries
suid_check() {
    echo -e "\n\n\e[1;34m[+] Checking SUID Binaries\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Timeout for the SUID check (in seconds)
    timeout_duration=15

    # Find all SUID binaries with a timeout
    suid_binaries=$(timeout "$timeout_duration" find / -type f -perm -4000 2>/dev/null)
    
    # Check if the timeout occurred
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] SUID check timed out after $timeout_duration seconds. Skipping...\e[0m"
    elif [ -z "$suid_binaries" ]; then
        echo -e "\e[1;31m[-] No SUID binaries found.\e[0m"
    else
        echo -e "\e[1;33m[!] SUID binaries found:\e[0m"

        suid_summary="SUID binaries detected. Review needed."

        # Highlight common dangerous SUID binaries
        while IFS= read -r binary; do
            case "$binary" in
                *bash|*sh|*perl|*python|*ruby|*lua)
                    echo -e "    \e[1;31m$binary\e[0m (Potentially dangerous: Interpreter)"
                    ;;
                */usr/bin/passwd|*/usr/bin/chsh|*/usr/bin/chfn|*/usr/bin/newgrp)
                    echo -e "    \e[1;33m$binary\e[0m (Common, check for misconfigurations)"
                    ;;
                *)
                    echo -e "    $binary"
                    ;;
            esac
        done <<< "$suid_binaries"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Check SGID binaries
sgid_check() {
    echo -e "\n\n\e[1;34m[+] Checking SGID Binaries\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Timeout for the SGID check (in seconds)
    timeout_duration=15

    # Find all SGID binaries with a timeout
    sgid_binaries=$(timeout "$timeout_duration" find / -type f -perm -2000 2>/dev/null)
    
    # Check if the timeout occurred
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] SGID check timed out after $timeout_duration seconds. Skipping...\e[0m"
    elif [ -z "$sgid_binaries" ]; then
        echo -e "\e[1;31m[-] No SGID binaries found.\e[0m"
    else
        echo -e "\e[1;33m[!] SGID binaries found:\e[0m"

        sgid_summary="SGID binaries detected. Review needed."

        # Highlight common dangerous SGID binaries
        while IFS= read -r binary; do
            case "$binary" in
                *mail|*write|*wall|*newgrp)
                    echo -e "    \e[1;31m$binary\e[0m (Potentially dangerous: Group access)"
                    ;;
                *)
                    echo -e "    $binary"
                    ;;
            esac
        done <<< "$sgid_binaries"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check for cronjobs
cron_check() {
    echo -e "\n\n\e[1;34m[+] Checking Cron Jobs\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary variable
    cron_summary="No writable cron jobs or misconfigurations detected."

    # Check /etc/crontab
    echo -e "\e[1;33m[!] /etc/crontab:\e[0m"
    if [ -f /etc/crontab ]; then
        echo -e "    \e[1;33mContents of /etc/crontab:\e[0m"
        cat /etc/crontab | sed 's/^/        /'
        
        # Check if /etc/crontab is writable
        if [ -w /etc/crontab ]; then
            echo -e "\e[1;31m[!] /etc/crontab is writable! Potential security risk.\e[0m"
            cron_summary="/etc/crontab is writable! Review required."
        else
            echo -e "    \e[1;32m/etc/crontab is not writable.\e[0m"
        fi
    else
        echo -e "    \e[1;31m/etc/crontab does not exist.\e[0m"
    fi

    # Check system-wide cron jobs
    echo -e "\n\e[1;33m[!] System-Wide Cron Jobs:\e[0m"
    if [ -d /etc/cron.d ]; then
        cron_files=$(ls /etc/cron.d 2>/dev/null)
        if [ -z "$cron_files" ]; then
            echo -e "    \e[1;31mNo cron jobs found in /etc/cron.d\e[0m"
        else
            for cron_file in $cron_files; do
                echo -e "    /etc/cron.d/$cron_file"
                cat /etc/cron.d/"$cron_file" | sed 's/^/        /'
            done
        fi
    else
        echo -e "    \e[1;31m/etc/cron.d directory not found.\e[0m"
    fi

    # Check user-specific cron jobs
    echo -e "\n\e[1;33m[!] User-Specific Cron Jobs:\e[0m"
    if command -v crontab >/dev/null 2>&1; then
        user_cron=$(crontab -l 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "    \e[1;33mCrontab entries for $(whoami):\e[0m"
            echo "$user_cron" | sed 's/^/        /'
        else
            echo -e "    \e[1;31mNo crontab entries for $(whoami).\e[0m"
        fi
    else
        echo -e "    \e[1;31mCrontab is not installed or not available for this user.\e[0m"
    fi

    # Check for writable cron files
    echo -e "\n\e[1;33m[!] Writable Cron Files:\e[0m"
    writable_cron_files=$(find /etc/cron* -type f -writable 2>/dev/null)
    if [ -z "$writable_cron_files" ]; then
        echo -e "    \e[1;31mNo writable cron files found.\e[0m"
    else
        echo -e "\e[1;31m[!] Writable cron files detected! Potential security risk:\e[0m"
        echo "$writable_cron_files" | sed 's/^/        /'
        cron_summary="Writable cron files detected! Review required."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check file capabilities
capabilities_check() {
    echo -e "\n\n\e[1;34m[+] Checking Capabilities\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary variable
    capabilities_summary="No dangerous file capabilities detected."

    # Timeout duration (in seconds)
    timeout_duration=15

    # Find files with capabilities using a timeout
    capabilities=$(timeout "$timeout_duration" getcap -r / 2>/dev/null)

    # Check if the timeout occurred
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Capabilities check timed out after $timeout_duration seconds. Skipping...\e[0m"
        capabilities_summary="Capabilities check timed out. Results incomplete."
    elif [ -z "$capabilities" ]; then
        echo -e "    \e[1;31mNo files with capabilities found.\e[0m"
    else
        echo -e "\e[1;33m[!] Files and their Capabilities:\e[0m"
        dangerous_found=0
        while IFS= read -r line; do
            # Highlight common dangerous capabilities
            if echo "$line" | grep -qE "(cap_setuid|cap_setgid|cap_dac_override|cap_net_admin|cap_net_raw)"; then
                echo -e "    \e[1;31m$line\e[0m (Potentially dangerous)"
                dangerous_found=1
            else
                echo -e "    $line"
            fi
        done <<< "$capabilities"

        if [ $dangerous_found -eq 1 ]; then
            capabilities_summary="Dangerous capabilities detected! Review needed."
        fi

    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check if we can write some critical files
check_writable_critical_files() {
    echo -e "\n\n\e[1;34m[+] Checking Writable Critical Files and Directories\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # List of critical files and directories to check
    critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/sudoers.d"
        "/etc/cron.d"
        "/etc/crontab"
        "/etc/ssh/sshd_config"
    )

    # Initialize the summary
    writable_files_summary="No writable critical files or directories detected."

    writable_files_found=0
    writable_directories_found=0

    for file in "${critical_files[@]}"; do
        if [ -e "$file" ]; then
            if [ -d "$file" ]; then
                # Check if the directory itself is writable
                if [ -w "$file" ]; then
                    echo -e "\e[1;31m[!] Writable Directory: $file (Potential Security Risk)\e[0m"
                    writable_directories_found=1
                fi
                # Check for writable files inside the directory
                writable_files=$(find "$file" -type f -writable 2>/dev/null)
                if [ -n "$writable_files" ]; then
                    for writable_file in $writable_files; do
                        echo -e "\e[1;31m[!] Writable: $writable_file (Potential Security Risk)\e[0m"
                        writable_files_found=1
                    done
                fi
            else
                # Check if the file is writable
                if [ -w "$file" ]; then
                    echo -e "\e[1;31m[!] Writable: $file (Potential Security Risk)\e[0m"
                    writable_files_found=1
                fi
            fi
        fi
    done

    # Update the summary
    if [ $writable_files_found -eq 0 ] && [ $writable_directories_found -eq 0 ]; then
        echo -e "\e[1;32m[+] No writable critical files or directories detected.\e[0m"
    else
        writable_files_summary="Writable critical files or directories detected. Review needed."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# search for potentially interesting files
search_interesting_files() {
    echo -e "\n\n\e[1;34m[+] Searching for Potentially Interesting Files\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary
    interesting_files_summary="No interesting files detected."

    # List of file extensions to search for
    file_extensions=".xls .xls* .xltx .csv .od* .doc .doc* .pdf .pot .pot* .pp* .key .conf .config .cnf"

    files_found=0

    # Iterate over extensions and search for files
    for ext in $file_extensions; do
        echo -e "\n\e[1;33m[!] File extension:\e[0m $ext"
        results=$(find / -name "*$ext" 2>/dev/null | grep -v "lib\|fonts\|share\|core")
        
        if [ -z "$results" ]; then
            echo -e "    \e[1;31mNo files found with this extension.\e[0m"
        else
            echo "$results" | sed 's/^/    /'
            files_found=1
        fi
    done

    # Update the summary
    if [ $files_found -eq 1 ]; then
        interesting_files_summary="Potentially interesting files detected. Review needed."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# search for potentially sensitive config files containing credentials
search_sensitive_content() {
    echo -e "\n\n\e[1;34m[+] Searching for Sensitive Content in Config Files\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary
    sensitive_content_summary="No sensitive content detected in config files."

    # Variable to track if sensitive content is found
    sensitive_found=0

    # Find .cnf, .conf, and .config files and search for sensitive content
    find / \( -name "*.cnf" -o -name "*.conf" -o -name "*.config" \) 2>/dev/null | grep -v "doc\|lib" | while read -r file; do
        matches=$(grep --color=always "password\|pass" "$file" 2>/dev/null | grep -v "\#")
        if [ -n "$matches" ]; then
            echo -e "\n\e[1;33m[!] File:\e[0m $file"
            echo "$matches" | sed 's/^/    /'
            sensitive_found=1
        fi
    done

    # Update the summary
    if [ $sensitive_found -eq 1 ]; then
        sensitive_content_summary="Sensitive content detected in config files. Review needed."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# search for SSH private keys
search_ssh_private_keys() {
    echo -e "\n\n\e[1;34m[+] Searching for SSH Private Keys\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary
    ssh_keys_summary="No SSH private keys found in common locations."

    # Get the script's absolute path
    script_path=$(realpath "$0")

    # Target common locations for SSH private keys
    target_dirs=(
        "/root"
        "/home"
        "/etc/ssh"
    )

    results_found=0

    for dir in "${target_dirs[@]}"; do
        if [ -d "$dir" ]; then
            # Use find to locate files, excluding the script itself, and then search for "PRIVATE KEY"
            find "$dir" -type f ! -path "$script_path" 2>/dev/null | while read -r file; do
                if grep -q "PRIVATE KEY" "$file" 2>/dev/null; then
                    echo -e "\e[1;33m[!] File:\e[0m $file"
                    grep --color=always "PRIVATE KEY" "$file" 2>/dev/null | sed 's/^/    /'
                    results_found=1
                fi
            done
        fi
    done

    # Update the summary based on results
    if [ $results_found -eq 1 ]; then
        ssh_keys_summary="SSH private keys detected. Review the findings for potential sensitive information."
    fi

    if [ $results_found -eq 0 ]; then
        echo -e "\e[1;31m[-] No SSH private keys found in common locations.\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# search and dump shell history files
dump_history_files() {
    echo -e "\n\n\e[1;34m[+] Searching for and Dumping Shell History Files\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary
    history_files_summary="No shell history files found or accessible."

    # Common history files to check
    history_files=(
        ".bash_history"
        ".zsh_history"
        ".ash_history"
        ".history"
        ".csh_history"
        ".ksh_history"
        ".tcsh_history"
        ".fish_history"
    )

    # Search for history files in common locations
    home_dirs=$(find /home /root -type d 2>/dev/null)
    found=0

    for home in $home_dirs; do
        for file in "${history_files[@]}"; do
            target="$home/$file"
            if [ -f "$target" ]; then
                echo -e "\e[1;33m[!] History File Found:\e[0m $target"
                echo -e "\e[1;33mContents:\e[0m"
                cat "$target" | sed 's/^/    /'
                echo
                found=1
            fi
        done
    done

    # Update the summary based on results
    if [ $found -eq 1 ]; then
        history_files_summary="Shell history files found. Review the findings for sensitive commands or credentials."
    fi

    if [ $found -eq 0 ]; then
        echo -e "\e[1;31m[-] No history files found or accessible.\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check writable systemd related files
check_systemd_writable() {
    echo -e "\n\n\e[1;34m[+] Checking systemd-related Privilege Escalation Vectors\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize the summary
    systemd_summary="No writable systemd files or misconfigurations detected."

    # Timeout duration
    timeout_duration=30

    # Check writable .service files
    echo -e "\e[1;33m[!] Searching for Writable .service Files...\e[0m"
    writable_services=$(timeout "$timeout_duration" find /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system -type f -name "*.service" -writable 2>/dev/null)
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Writable .service file check timed out.\e[0m"
    elif [ -z "$writable_services" ]; then
        echo -e "\e[1;31m[-] No writable .service files found.\e[0m"
    else
        echo -e "\e[1;33m[!] Writable .service Files Found:\e[0m"
        echo "$writable_services" | sed 's/^/    /'
        systemd_summary="Writable .service files detected. Review for privilege escalation opportunities."
    fi

    # Check writable binaries executed by services
    echo -e "\n\e[1;33m[!] Searching for Writable Binaries Executed by Services...\e[0m"
    writable_binaries=()
    for service_file in $(find /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system -type f -name "*.service" 2>/dev/null); do
        binary=$(grep -E "ExecStart=" "$service_file" | sed 's/^.*=//' | awk '{print $1}' | xargs realpath 2>/dev/null)
        if [ -n "$binary" ] && [ -w "$binary" ]; then
            writable_binaries+=("$binary (from $service_file)")
        fi
    done
    if [ ${#writable_binaries[@]} -eq 0 ]; then
        echo -e "\e[1;31m[-] No writable binaries executed by services found.\e[0m"
    else
        echo -e "\e[1;33m[!] Writable Binaries Executed by Services Found:\e[0m"
        printf "    %s\n" "${writable_binaries[@]}"
        systemd_summary="Writable binaries executed by services detected. Review for potential abuse."
    fi

    # Check writable folders in systemd PATH
    echo -e "\n\e[1;33m[!] Searching for Writable Folders in systemd PATH...\e[0m"
    systemd_paths=$(systemctl show --property=UnitPath | cut -d= -f2 | tr ':' '\n')
    writable_dirs=()
    for dir in $systemd_paths; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            writable_dirs+=("$dir")
        fi
    done
    if [ ${#writable_dirs[@]} -eq 0 ]; then
        echo -e "\e[1;31m[-] No writable folders in systemd PATH found.\e[0m"
    else
        echo -e "\e[1;33m[!] Writable Folders in systemd PATH Found:\e[0m"
        printf "    %s\n" "${writable_dirs[@]}"
        systemd_summary="Writable folders in systemd PATH detected. Check for privilege escalation opportunities."
    fi

    # Check writable timers
    echo -e "\n\e[1;33m[!] Searching for Writable Timers...\e[0m"
    writable_timers=$(timeout "$timeout_duration" find /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system -type f -name "*.timer" -writable 2>/dev/null)
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Writable timer check timed out.\e[0m"
    elif [ -z "$writable_timers" ]; then
        echo -e "\e[1;31m[-] No writable timers found.\e[0m"
    else
        echo -e "\e[1;33m[!] Writable Timers Found:\e[0m"
        echo "$writable_timers" | sed 's/^/    /'
        systemd_summary="Writable timers detected. Investigate for potential abuse."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check for writable files and folders
check_writable_by_user() {
    echo -e "\n\n\e[1;34m[+] Checking Files and Directories Writable by Current User\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Initialize summary
    writable_files_dirs_summary="No writable files or directories detected for the current user."

    # Timeout for the check (in seconds)
    timeout_duration=30

    current_user=$(whoami)

    echo -e "\e[1;33m[!] Searching for Files Writable by $current_user...\e[0m"
    user_writable_files=$(timeout "$timeout_duration" find / -type f -writable \
        ! -path "/proc/*" \
        ! -path "/sys/*" \
        ! -path "/tmp/*" \
        ! -path "/run/*" 2>/dev/null)

    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Writable file check timed out after $timeout_duration seconds. Skipping...\e[0m"
    elif [ -z "$user_writable_files" ]; then
        echo -e "\e[1;31m[-] No files writable by $current_user found.\e[0m"
    else
        echo -e "\e[1;33m[!] Files Writable by $current_user:\e[0m"
        echo "$user_writable_files" | sed 's/^/    /'
        writable_files_dirs_summary="Writable files detected for the current user. Review required."
    fi

    echo -e "\n\e[1;33m[!] Searching for Directories Writable by $current_user...\e[0m"
    user_writable_dirs=$(timeout "$timeout_duration" find / -type d -writable \
        ! -path "/proc/*" \
        ! -path "/sys/*" \
        ! -path "/tmp/*" \
        ! -path "/run/*" 2>/dev/null)

    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Writable directory check timed out after $timeout_duration seconds. Skipping...\e[0m"
    elif [ -z "$user_writable_dirs" ]; then
        echo -e "\e[1;31m[-] No directories writable by $current_user found.\e[0m"
    else
        echo -e "\e[1;33m[!] Directories Writable by $current_user:\e[0m"
        echo "$user_writable_dirs" | sed 's/^/    /'
        writable_files_dirs_summary="Writable directories detected for the current user. Review required."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Update the summary if writable files or directories are found
    if [ -n "$user_writable_files" ] || [ -n "$user_writable_dirs" ]; then
        writable_files_dirs_summary="Writable files and/or directories detected for the current user. Review required."
    fi
}

print_summary() {
    echo -e "\n\e[1;34m[+] Summary\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    
    # Function to check if summary contains "Review needed"
    highlight_summary() {
        local summary_text=$1
        if echo "$summary_text" | grep -q "Review needed"; then
            echo -e "\e[1;31m$summary_text\e[0m"  # Red text for review needed
        else
            echo "$summary_text"  # Default color for no issues
        fi
    }

    echo -e "\e[1;33m[OS Information]:\e[0m $os_info_summary"
    echo -e "\e[1;33m[User Information]:\e[0m $user_info_summary"
    echo -e "\e[1;33m[Sudo Privileges]:\e[0m $(highlight_summary "$sudo_priv_summary")"
    echo -e "\e[1;33m[SUID Binaries]:\e[0m $(highlight_summary "$suid_summary")"
    echo -e "\e[1;33m[SGID Binaries]:\e[0m $(highlight_summary "$sgid_summary")"
    echo -e "\e[1;33m[Cron Jobs]:\e[0m $(highlight_summary "$cron_summary")"
    echo -e "\e[1;33m[Capabilities]:\e[0m $(highlight_summary "$capabilities_summary")"
    echo -e "\e[1;33m[Writable Files]:\e[0m $(highlight_summary "$writable_files_summary")"
    echo -e "\e[1;33m[Interesting Files]:\e[0m $(highlight_summary "$interesting_files_summary")"
    echo -e "\e[1;33m[Sensitive Content]:\e[0m $(highlight_summary "$sensitive_content_summary")"
    echo -e "\e[1;33m[SSH Private Keys]:\e[0m $(highlight_summary "$ssh_keys_summary")"
    echo -e "\e[1;33m[Docker Detection]:\e[0m $docker_summary"
    echo -e "\e[1;33m[Environment Variables]:\e[0m $(highlight_summary "$env_vars_summary")"
    echo -e "\e[1;33m[Systemd Configurations]:\e[0m $(highlight_summary "$systemd_summary")"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check if the machine is domain joined
check_ad_integration

# Check if running as root
check_if_root

# Clear the screen for a clean start
clear

# display ascii art
ascii_art

# Add some spacing
echo -e "\n"

# Display OS information
os_info

# Add some spacing
echo -e "\n"

# enum current user and group info
user_info

# Add some spacing
echo -e "\n"

# enum sudo check
sudo_check

# Add some spacing
echo -e "\n"

# Check environment variables for sensitive information
check_env_variables

# Add some spacing
echo -e "\n"

# check SUID binaries
suid_check

# Add some spacing
echo -e "\n"

# check SGID binaries
sgid_check

# Add some spacing
echo -e "\n"

# check for cronjobs
cron_check

# Add some spacing
echo -e "\n"

# check for files with capabilities
capabilities_check

# Add some spacing
echo -e "\n"

# check if we can write some critical files
check_writable_critical_files

# Add some spacing
echo -e "\n"

# search for potentially interesting files
search_interesting_files

# Add some spacing
echo -e "\n"

# search for potentially sensitive config files containing credentials
search_sensitive_content

# Add some spacing
echo -e "\n"

# search for SSH private keys
search_ssh_private_keys

# Add some spacing
echo -e "\n"

# search and dump shell history files
dump_history_files

# Add some spacing
echo -e "\n"

# check writable systemd related files
check_systemd_writable

# Add some spacing
echo -e "\n"

# check for writable files and folders
check_writable_by_user

# Add some spacing
echo -e "\n"

# Call the summary function
print_summary