#!/usr/bin/env bash

# Function to print ASCII art
ascii_art() {
cat << "EOF"
  __  __             _      _     _       ____                 
 |  \/  | __ _  __ _(_) ___| |   (_)_ __ |  _ \__      ___ __  
 | |\/| |/ _` |/ _` | |/ __| |   | | '_ \| |_) \ \ /\ / / '_ \ 
 | |  | | (_| | (_| | | (__| |___| | | | |  __/ \ V  V /| | | |
 |_|  |_|\__,_|\__, |_|\___|_____|_|_| |_|_|     \_/\_/ |_| |_|
               |___/                                           
                                                 
     Linux Privilege Escalation Script
             By @Mag1cByt3s
EOF
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

# display ascii art
ascii_art

# Add some spacing
echo -e "\n"

# enum current user and group info
user_info
