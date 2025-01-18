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

# display ascii art
ascii_art

# Add some spacing
echo -e "\n"

# Display OS information
os_info

# enum current user and group info
user_info

# enum sudo check
sudo_check