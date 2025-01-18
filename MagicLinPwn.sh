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

# Function to highlight specific groups
highlight_groups() {
    local group=$1
    case "$group" in
        wheel|docker|lxd|sudo|libvirtd|kvm|disk|www-data|apache|nginx|shadow|root|staff|backup|operator)
            echo -e "\e[1;31m$group\e[0m"  # Highlight in bold red
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
    
    # Kernel version
    echo -e "\e[1;33mKernel Version:\e[0m $(uname -r)"
    
    # Distro name and version
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "\e[1;33mDistro Name:\e[0m $NAME"
        echo -e "\e[1;33mDistro Version:\e[0m $VERSION"
    else
        echo -e "\e[1;33mDistro Name:\e[0m Unknown"
        echo -e "\e[1;33mDistro Version:\e[0m Unknown"
    fi
    
    # Architecture
    echo -e "\e[1;33mArchitecture:\e[0m $(uname -m)"
    
    # Hostname
    echo -e "\e[1;33mHostname:\e[0m $(hostname)"
    
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display current user and group memberships
user_info() {
    echo -e "\n\n\e[1;34m[+] Gathering User Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    
    # Display the current user
    echo -e "\e[1;33mCurrent User:\e[0m $(whoami)"
    
    # Display the current user's UID and GID
    echo -e "\e[1;33mUser ID (UID):\e[0m $(id -u)"
    echo -e "\e[1;33mGroup ID (GID):\e[0m $(id -g)"
    
    # Display the user's primary group
    echo -e "\e[1;33mPrimary Group:\e[0m $(id -gn)"
    
    # Display all groups with wrapping
    echo -ne "\e[1;33mGroup Memberships:\e[0m "
    id -Gn | tr ' ' '\n' | while read group; do
        # Highlight specific groups
        highlighted_group=$(highlight_groups "$group")
        echo -n "$highlighted_group, "
    done | sed 's/, $//' | fold -s -w 50 | sed '1!s/^/             /'
    
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to check and highlight sudo permissions
sudo_check() {
    echo -e "\n\n\e[1;34m[+] Checking Sudo Privileges\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Check if sudo is installed
    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "\e[1;31m[-] Sudo is not installed on this system.\e[0m"
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

    # Check /etc/crontab
    echo -e "\e[1;33m[!] /etc/crontab:\e[0m"
    if [ -f /etc/crontab ]; then
        echo -e "    \e[1;33mContents of /etc/crontab:\e[0m"
        cat /etc/crontab | sed 's/^/        /'
        
        # Check if /etc/crontab is writable
        if [ -w /etc/crontab ]; then
            echo -e "\e[1;31m[!] /etc/crontab is writable! Potential security risk.\e[0m"
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
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check file capabilities
capabilities_check() {
    echo -e "\n\n\e[1;34m[+] Checking Capabilities\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # Timeout duration (in seconds)
    timeout_duration=15

    # Find files with capabilities using a timeout
    capabilities=$(timeout "$timeout_duration" getcap -r / 2>/dev/null)

    # Check if the timeout occurred
    if [ $? -eq 124 ]; then
        echo -e "\e[1;31m[-] Capabilities check timed out after $timeout_duration seconds. Skipping...\e[0m"
    elif [ -z "$capabilities" ]; then
        echo -e "    \e[1;31mNo files with capabilities found.\e[0m"
    else
        echo -e "\e[1;33m[!] Files and their Capabilities:\e[0m"
        while IFS= read -r line; do
            # Highlight common dangerous capabilities
            if echo "$line" | grep -qE "(cap_setuid|cap_setgid|cap_dac_override|cap_net_admin|cap_net_raw)"; then
                echo -e "    \e[1;31m$line\e[0m (Potentially dangerous)"
            else
                echo -e "    $line"
            fi
        done <<< "$capabilities"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# check if we can write some critical files
check_writable_critical_files() {
    echo -e "\n\n\e[1;34m[+] Checking Writable Critical Files\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    # List of critical files to check
    critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/cron.d"
        "/etc/crontab"
        "/etc/ssh/sshd_config"
    )

    writable_found=0

    for file in "${critical_files[@]}"; do
        if [ -e "$file" ]; then
            if [ -w "$file" ]; then
                echo -e "\e[1;31m[!] Writable: $file (Potential Security Risk)\e[0m"
                writable_found=1
            else
                echo -e "    $file is not writable."
            fi
        fi
    done

    if [ $writable_found -eq 0 ]; then
        echo -e "\e[1;32m[+] No writable critical files detected.\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

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