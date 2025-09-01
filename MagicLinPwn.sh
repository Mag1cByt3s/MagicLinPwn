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

# Define colors
C=$(printf '\033')
SED_RED="${C}[1;31m&${C}[0m"

# test if sed supports -E or -r
E=E
echo | sed -${E} 's/o/a/' 2>/dev/null
if [ $? -ne 0 ] ; then
	echo | sed -r 's/o/a/' 2>/dev/null
	if [ $? -eq 0 ] ; then
		E=r
	else
        echo -e "\e[1;33mWARNING: No suitable option found for extended regex with sed. Continuing but the results might be unreliable.\e[0m"
	fi
fi

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
            echo -e "    \e[1;33m[!] Adm Group:\e[0m Can read logs, useful for privilege escalation via credential leaks."
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

run_les() {
    if command -v bash >/dev/null 2>&1; then
        echo -e "\n\n\e[1;34m[+] Executing Linux Exploit Suggester\e[0m"
        echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
        
        echo -e "\e[1;33mhttps://github.com/mzet-/linux-exploit-suggester\e[0m"
        les_b64="IyEvYmluL2Jhc2gKCiMKIyBDb3B5cmlnaHQgKGMpIDIwMTYtMjAyMywgaHR0cHM6Ly9naXRodWIuY29tL216ZXQtCiMKIyBsaW51eC1leHBsb2l0LXN1Z2dlc3Rlci5zaCBjb21lcyB3aXRoIEFCU09MVVRFTFkgTk8gV0FSUkFOVFkuCiMgVGhpcyBpcyBmcmVlIHNvZnR3YXJlLCBhbmQgeW91IGFyZSB3ZWxjb21lIHRvIHJlZGlzdHJpYnV0ZSBpdAojIHVuZGVyIHRoZSB0ZXJtcyBvZiB0aGUgR05VIEdlbmVyYWwgUHVibGljIExpY2Vuc2UuIFNlZSBMSUNFTlNFCiMgZmlsZSBmb3IgdXNhZ2Ugb2YgdGhpcyBzb2Z0d2FyZS4KIwoKVkVSU0lPTj12MS4xCgojIGJhc2ggY29sb3JzCiN0eHRyZWQ9IlxlWzA7MzFtIgp0eHRyZWQ9IlxlWzkxOzFtIgp0eHRncm49IlxlWzE7MzJtIgp0eHRncmF5PSJcZVswOzM3bSIKdHh0Ymx1PSJcZVswOzM2bSIKdHh0cnN0PSJcZVswbSIKYmxkd2h0PSdcZVsxOzM3bScKd2h0PSdcZVswOzM2bScKYmxkYmx1PSdcZVsxOzM0bScKeWVsbG93PSdcZVsxOzkzbScKbGlnaHR5ZWxsb3c9J1xlWzA7OTNtJwoKIyBpbnB1dCBkYXRhClVOQU1FX0E9IiIKCiMgcGFyc2VkIGRhdGEgZm9yIGN1cnJlbnQgT1MKS0VSTkVMPSIiCk9TPSIiCkRJU1RSTz0iIgpBUkNIPSIiClBLR19MSVNUPSIiCgojIGtlcm5lbCBjb25maWcKS0NPTkZJRz0iIgoKQ1ZFTElTVF9GSUxFPSIiCgpvcHRfZmV0Y2hfYmlucz1mYWxzZQpvcHRfZmV0Y2hfc3Jjcz1mYWxzZQpvcHRfa2VybmVsX3ZlcnNpb249ZmFsc2UKb3B0X3VuYW1lX3N0cmluZz1mYWxzZQpvcHRfcGtnbGlzdF9maWxlPWZhbHNlCm9wdF9jdmVsaXN0X2ZpbGU9ZmFsc2UKb3B0X2NoZWNrc2VjX21vZGU9ZmFsc2UKb3B0X2Z1bGw9ZmFsc2UKb3B0X3N1bW1hcnk9ZmFsc2UKb3B0X2tlcm5lbF9vbmx5PWZhbHNlCm9wdF91c2Vyc3BhY2Vfb25seT1mYWxzZQpvcHRfc2hvd19kb3M9ZmFsc2UKb3B0X3NraXBfbW9yZV9jaGVja3M9ZmFsc2UKb3B0X3NraXBfcGtnX3ZlcnNpb25zPWZhbHNlCgpBUkdTPQpTSE9SVE9QVFM9ImhWZmJzdTprOmRwOmciCkxPTkdPUFRTPSJoZWxwLHZlcnNpb24sZnVsbCxmZXRjaC1iaW5hcmllcyxmZXRjaC1zb3VyY2VzLHVuYW1lOixrZXJuZWw6LHNob3ctZG9zLHBrZ2xpc3QtZmlsZTosc2hvcnQsa2VybmVsc3BhY2Utb25seSx1c2Vyc3BhY2Utb25seSxza2lwLW1vcmUtY2hlY2tzLHNraXAtcGtnLXZlcnNpb25zLGN2ZWxpc3QtZmlsZTosY2hlY2tzZWMiCgojIyBleHBsb2l0cyBkYXRhYmFzZQpkZWNsYXJlIC1hIEVYUExPSVRTCmRlY2xhcmUgLWEgRVhQTE9JVFNfVVNFUlNQQUNFCgojIyB0ZW1wb3JhcnkgYXJyYXkgZm9yIHB1cnBvc2Ugb2Ygc29ydGluZyBleHBsb2l0cyAoYmFzZWQgb24gZXhwbG9pdHMnIHJhbmspCmRlY2xhcmUgLWEgZXhwbG9pdHNfdG9fc29ydApkZWNsYXJlIC1hIFNPUlRFRF9FWFBMT0lUUwoKIyMjIyMjIyMjIyMjIExJTlVYIEtFUk5FTFNQQUNFIEVYUExPSVRTICMjIyMjIyMjIyMjIyMjIyMjIyMjCm49MAoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA0LTEyMzVdJHt0eHRyc3R9IGVsZmxibApSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj0yLjQuMjkKVGFnczoKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9pc2VjLnBsL3Z1bG5lcmFiaWxpdGllcy9pc2VjLTAwMjEtdXNlbGliLnR4dApiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxMTExMDMwNDI5MDQvaHR0cDovL3RhcmFudHVsYS5ieS5ydS9sb2NhbHJvb3QvMi42LngvZWxmbGJsCmV4cGxvaXQtZGI6IDc0NApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA0LTEyMzVdJHt0eHRyc3R9IHVzZWxpYigpClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPTIuNC4yOQpUYWdzOgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL2lzZWMucGwvdnVsbmVyYWJpbGl0aWVzL2lzZWMtMDAyMS11c2VsaWIudHh0CmV4cGxvaXQtZGI6IDc3OApDb21tZW50czogS25vd24gdG8gd29yayBvbmx5IGZvciAyLjQgc2VyaWVzIChldmVuIHRob3VnaCAyLjYgaXMgYWxzbyB2dWxuZXJhYmxlKQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA0LTEyMzVdJHt0eHRyc3R9IGtyYWQzClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuNSx2ZXI8PTIuNi4xMQpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDEzOTcKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNC0wMDc3XSR7dHh0cnN0fSBtcmVtYXBfcHRlClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMCx2ZXI8PTIuNi4yClRhZ3M6ClJhbms6IDEKZXhwbG9pdC1kYjogMTYwCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDYtMjQ1MV0ke3R4dHJzdH0gcmFwdG9yX3ByY3RsClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMTMsdmVyPD0yLjYuMTcKVGFnczoKUmFuazogMQpleHBsb2l0LWRiOiAyMDMxCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDYtMjQ1MV0ke3R4dHJzdH0gcHJjdGwKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xMyx2ZXI8PTIuNi4xNwpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDIwMDQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNi0yNDUxXSR7dHh0cnN0fSBwcmN0bDIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xMyx2ZXI8PTIuNi4xNwpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDIwMDUKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNi0yNDUxXSR7dHh0cnN0fSBwcmN0bDMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xMyx2ZXI8PTIuNi4xNwpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDIwMDYKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNi0yNDUxXSR7dHh0cnN0fSBwcmN0bDQKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xMyx2ZXI8PTIuNi4xNwpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDIwMTEKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNi0zNjI2XSR7dHh0cnN0fSBoMDBseXNoaXQKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi44LHZlcjw9Mi42LjE2ClRhZ3M6ClJhbms6IDEKYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTExMTAzMDQyOTA0L2h0dHA6Ly90YXJhbnR1bGEuYnkucnUvbG9jYWxyb290LzIuNi54L2gwMGx5c2hpdApleHBsb2l0LWRiOiAyMDEzCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDgtMDYwMF0ke3R4dHJzdH0gdm1zcGxpY2UxClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMTcsdmVyPD0yLjYuMjQKVGFnczoKUmFuazogMQpleHBsb2l0LWRiOiA1MDkyCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDgtMDYwMF0ke3R4dHJzdH0gdm1zcGxpY2UyClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMjMsdmVyPD0yLjYuMjQKVGFnczoKUmFuazogMQpleHBsb2l0LWRiOiA1MDkzCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDgtNDIxMF0ke3R4dHJzdH0gZnRyZXgKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xMSx2ZXI8PTIuNi4yMgpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDY4NTEKQ29tbWVudHM6IHdvcmxkLXdyaXRhYmxlIHNnaWQgZGlyZWN0b3J5IGFuZCBzaGVsbCB0aGF0IGRvZXMgbm90IGRyb3Agc2dpZCBwcml2cyB1cG9uIGV4ZWMgKGFzaC9zYXNoKSBhcmUgcmVxdWlyZWQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwOC00MjEwXSR7dHh0cnN0fSBleGl0X25vdGlmeQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjI1LHZlcjw9Mi42LjI5ClRhZ3M6ClJhbms6IDEKZXhwbG9pdC1kYjogODM2OQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OTJdJHt0eHRyc3R9IHNvY2tfc2VuZHBhZ2UgKHNpbXBsZSB2ZXJzaW9uKQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjAsdmVyPD0yLjYuMzAKVGFnczogdWJ1bnR1PTcuMTAsUkhFTD00LGZlZG9yYT00fDV8Nnw3fDh8OXwxMHwxMQpSYW5rOiAxCmV4cGxvaXQtZGI6IDk0NzkKQ29tbWVudHM6IFdvcmtzIGZvciBzeXN0ZW1zIHdpdGggL3Byb2Mvc3lzL3ZtL21tYXBfbWluX2FkZHIgZXF1YWwgdG8gMApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OTIsQ1ZFLTIwMDktMTg5NV0ke3R4dHJzdH0gc29ja19zZW5kcGFnZQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjAsdmVyPD0yLjYuMzAKVGFnczogdWJ1bnR1PTkuMDQKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8veG9ybC53b3JkcHJlc3MuY29tLzIwMDkvMDcvMTYvY3ZlLTIwMDktMTg5NS1saW51eC1rZXJuZWwtcGVyX2NsZWFyX29uX3NldGlkLXBlcnNvbmFsaXR5LWJ5cGFzcy8Kc3JjLXVybDogaHR0cHM6Ly9naXRsYWIuY29tL2V4cGxvaXQtZGF0YWJhc2UvZXhwbG9pdGRiLWJpbi1zcGxvaXRzLy0vcmF3L21haW4vYmluLXNwbG9pdHMvOTQzNS50Z3oKZXhwbG9pdC1kYjogOTQzNQpDb21tZW50czogL3Byb2Mvc3lzL3ZtL21tYXBfbWluX2FkZHIgbmVlZHMgdG8gZXF1YWwgMCBPUiBwdWxzZWF1ZGlvIG5lZWRzIHRvIGJlIGluc3RhbGxlZApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OTIsQ1ZFLTIwMDktMTg5NV0ke3R4dHJzdH0gc29ja19zZW5kcGFnZTIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4wLHZlcjw9Mi42LjMwClRhZ3M6IApSYW5rOiAxCnNyYy11cmw6IGh0dHBzOi8vZ2l0bGFiLmNvbS9leHBsb2l0LWRhdGFiYXNlL2V4cGxvaXRkYi1iaW4tc3Bsb2l0cy8tL3Jhdy9tYWluL2Jpbi1zcGxvaXRzLzk0MzYudGd6CmV4cGxvaXQtZGI6IDk0MzYKQ29tbWVudHM6IFdvcmtzIGZvciBzeXN0ZW1zIHdpdGggL3Byb2Mvc3lzL3ZtL21tYXBfbWluX2FkZHIgZXF1YWwgdG8gMApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OTIsQ1ZFLTIwMDktMTg5NV0ke3R4dHJzdH0gc29ja19zZW5kcGFnZTMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4wLHZlcjw9Mi42LjMwClRhZ3M6IApSYW5rOiAxCnNyYy11cmw6IGh0dHBzOi8vZ2l0bGFiLmNvbS9leHBsb2l0LWRhdGFiYXNlL2V4cGxvaXRkYi1iaW4tc3Bsb2l0cy8tL3Jhdy9tYWluL2Jpbi1zcGxvaXRzLzk2NDEudGFyLmd6CmV4cGxvaXQtZGI6IDk2NDEKQ29tbWVudHM6IC9wcm9jL3N5cy92bS9tbWFwX21pbl9hZGRyIG5lZWRzIHRvIGVxdWFsIDAgT1IgcHVsc2VhdWRpbyBuZWVkcyB0byBiZSBpbnN0YWxsZWQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwOS0yNjkyLENWRS0yMDA5LTE4OTVdJHt0eHRyc3R9IHNvY2tfc2VuZHBhZ2UgKHBwYykKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4wLHZlcjw9Mi42LjMwClRhZ3M6IHVidW50dT04LjEwLFJIRUw9NHw1ClJhbms6IDEKZXhwbG9pdC1kYjogOTU0NQpDb21tZW50czogL3Byb2Mvc3lzL3ZtL21tYXBfbWluX2FkZHIgbmVlZHMgdG8gZXF1YWwgMApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OThdJHt0eHRyc3R9IHRoZSByZWJlbCAodWRwX3NlbmRtc2cpClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMSx2ZXI8PTIuNi4xOQpUYWdzOiBkZWJpYW49NApSYW5rOiAxCnNyYy11cmw6IGh0dHBzOi8vZ2l0bGFiLmNvbS9leHBsb2l0LWRhdGFiYXNlL2V4cGxvaXRkYi1iaW4tc3Bsb2l0cy8tL3Jhdy9tYWluL2Jpbi1zcGxvaXRzLzk1NzQudGd6CmV4cGxvaXQtZGI6IDk1NzQKYW5hbHlzaXMtdXJsOiBodHRwczovL2Jsb2cuY3IwLm9yZy8yMDA5LzA4L2N2ZS0yMDA5LTI2OTgtdWRwc2VuZG1zZy12dWxuZXJhYmlsaXR5Lmh0bWwKYXV0aG9yOiBzcGVuZGVyCkNvbW1lbnRzOiAvcHJvYy9zeXMvdm0vbW1hcF9taW5fYWRkciBuZWVkcyB0byBlcXVhbCAwIE9SIHB1bHNlYXVkaW8gbmVlZHMgdG8gYmUgaW5zdGFsbGVkCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDktMjY5OF0ke3R4dHJzdH0gaG9hZ2llX3VkcF9zZW5kbXNnClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMSx2ZXI8PTIuNi4xOSx4ODYKVGFnczogZGViaWFuPTQKUmFuazogMQpleHBsb2l0LWRiOiA5NTc1CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9ibG9nLmNyMC5vcmcvMjAwOS8wOC9jdmUtMjAwOS0yNjk4LXVkcHNlbmRtc2ctdnVsbmVyYWJpbGl0eS5odG1sCmF1dGhvcjogYW5kaQpDb21tZW50czogV29ya3MgZm9yIHN5c3RlbXMgd2l0aCAvcHJvYy9zeXMvdm0vbW1hcF9taW5fYWRkciBlcXVhbCB0byAwCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDktMjY5OF0ke3R4dHJzdH0ga2F0b24gKHVkcF9zZW5kbXNnKQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjEsdmVyPD0yLjYuMTkseDg2ClRhZ3M6IGRlYmlhbj00ClJhbms6IDEKc3JjLXVybDogaHR0cHM6Ly9naXRodWIuY29tL0thYm90L1VuaXgtUHJpdmlsZWdlLUVzY2FsYXRpb24tRXhwbG9pdHMtUGFjay9yYXcvbWFzdGVyLzIwMDkvQ1ZFLTIwMDktMjY5OC9rYXRvbi5jCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9ibG9nLmNyMC5vcmcvMjAwOS8wOC9jdmUtMjAwOS0yNjk4LXVkcHNlbmRtc2ctdnVsbmVyYWJpbGl0eS5odG1sCmF1dGhvcjogVnhIZWxsIExhYnMKQ29tbWVudHM6IFdvcmtzIGZvciBzeXN0ZW1zIHdpdGggL3Byb2Mvc3lzL3ZtL21tYXBfbWluX2FkZHIgZXF1YWwgdG8gMApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTI2OThdJHt0eHRyc3R9IGlwX2FwcGVuZF9kYXRhClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMSx2ZXI8PTIuNi4xOSx4ODYKVGFnczogZmVkb3JhPTR8NXw2LFJIRUw9NApSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9ibG9nLmNyMC5vcmcvMjAwOS8wOC9jdmUtMjAwOS0yNjk4LXVkcHNlbmRtc2ctdnVsbmVyYWJpbGl0eS5odG1sCmV4cGxvaXQtZGI6IDk1NDIKYXV0aG9yOiBwMGM3M24xCkNvbW1lbnRzOiBXb3JrcyBmb3Igc3lzdGVtcyB3aXRoIC9wcm9jL3N5cy92bS9tbWFwX21pbl9hZGRyIGVxdWFsIHRvIDAKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwOS0zNTQ3XSR7dHh0cnN0fSBwaXBlLmMgMQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjAsdmVyPD0yLjYuMzEKVGFnczoKUmFuazogMQpleHBsb2l0LWRiOiAzMzMyMQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDA5LTM1NDddJHt0eHRyc3R9IHBpcGUuYyAyClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMCx2ZXI8PTIuNi4zMQpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDMzMzIyCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDktMzU0N10ke3R4dHJzdH0gcGlwZS5jIDMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4wLHZlcjw9Mi42LjMxClRhZ3M6ClJhbms6IDEKZXhwbG9pdC1kYjogMTAwMTgKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMC0zMzAxXSR7dHh0cnN0fSBwdHJhY2Vfa21vZDIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4yNix2ZXI8PTIuNi4zNApUYWdzOiBkZWJpYW49Ni4we2tlcm5lbDoyLjYuKDMyfDMzfDM0fDM1KS0oMXwyfHRydW5rKS1hbWQ2NH0sdWJ1bnR1PSgxMC4wNHwxMC4xMCl7a2VybmVsOjIuNi4oMzJ8MzUpLSgxOXwyMXwyNCktc2VydmVyfQpSYW5rOiAxCmJpbi11cmw6IGh0dHBzOi8vd2ViLmFyY2hpdmUub3JnL3dlYi8yMDExMTEwMzA0MjkwNC9odHRwOi8vdGFyYW50dWxhLmJ5LnJ1L2xvY2Fscm9vdC8yLjYueC9rbW9kMgpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxMTExMDMwNDI5MDQvaHR0cDovL3RhcmFudHVsYS5ieS5ydS9sb2NhbHJvb3QvMi42LngvcHRyYWNlLWttb2QKYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTYwNjAyMTkyNjQxL2h0dHBzOi8vd3d3Lmtlcm5lbC1leHBsb2l0cy5jb20vbWVkaWEvcHRyYWNlX2ttb2QyLTY0CmV4cGxvaXQtZGI6IDE1MDIzCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTAtMTE0Nl0ke3R4dHJzdH0gcmVpc2VyZnMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xOCx2ZXI8PTIuNi4zNApUYWdzOiB1YnVudHU9OS4xMApSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9qb24ub2JlcmhlaWRlLm9yZy9ibG9nLzIwMTAvMDQvMTAvcmVpc2VyZnMtcmVpc2VyZnNfcHJpdi12dWxuZXJhYmlsaXR5LwpzcmMtdXJsOiBodHRwczovL2pvbi5vYmVyaGVpZGUub3JnL2ZpbGVzL3RlYW0tZWR3YXJkLnB5CmV4cGxvaXQtZGI6IDEyMTMwCmNvbW1lbnRzOiBSZXF1aXJlcyBhIFJlaXNlckZTIGZpbGVzeXN0ZW0gbW91bnRlZCB3aXRoIGV4dGVuZGVkIGF0dHJpYnV0ZXMKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMC0yOTU5XSR7dHh0cnN0fSBjYW5fYmNtClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMTgsdmVyPD0yLjYuMzYKVGFnczogdWJ1bnR1PTEwLjA0e2tlcm5lbDoyLjYuMzItMjQtZ2VuZXJpY30KUmFuazogMQpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2NDEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9jYW5fYmNtCmV4cGxvaXQtZGI6IDE0ODE0CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTAtMzkwNF0ke3R4dHJzdH0gcmRzClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMzAsdmVyPDIuNi4zNwpUYWdzOiBkZWJpYW49Ni4we2tlcm5lbDoyLjYuKDMxfDMyfDM0fDM1KS0oMXx0cnVuayktYW1kNjR9LHVidW50dT0xMC4xMHw5LjEwLGZlZG9yYT0xM3trZXJuZWw6Mi42LjMzLjMtODUuZmMxMy5pNjg2LlBBRX0sdWJ1bnR1PTEwLjA0e2tlcm5lbDoyLjYuMzItKDIxfDI0KS1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3d3dy5zZWN1cml0eWZvY3VzLmNvbS9hcmNoaXZlLzEvNTE0Mzc5CnNyYy11cmw6IGh0dHA6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTAxMDIwMDQ0MDQ4L2h0dHA6Ly93d3cudnNlY3VyaXR5LmNvbS9kb3dubG9hZC90b29scy9saW51eC1yZHMtZXhwbG9pdC5jCmJpbi11cmw6IGh0dHBzOi8vd2ViLmFyY2hpdmUub3JnL3dlYi8yMDE2MDYwMjE5MjY0MS9odHRwczovL3d3dy5rZXJuZWwtZXhwbG9pdHMuY29tL21lZGlhL3JkcwpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2NDEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9yZHM2NApleHBsb2l0LWRiOiAxNTI4NQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEwLTM4NDgsQ1ZFLTIwMTAtMzg1MCxDVkUtMjAxMC00MDczXSR7dHh0cnN0fSBoYWxmX25lbHNvbgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjAsdmVyPD0yLjYuMzYKVGFnczogdWJ1bnR1PSgxMC4wNHw5LjEwKXtrZXJuZWw6Mi42LigzMXwzMiktKDE0fDIxKS1zZXJ2ZXJ9ClJhbms6IDEKYmluLXVybDogaHR0cDovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2MzEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9oYWxmLW5lbHNvbjMKZXhwbG9pdC1kYjogMTc3ODcKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtOL0FdJHt0eHRyc3R9IGNhcHNfdG9fcm9vdApSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjM0LHZlcjw9Mi42LjM2LHg4NgpUYWdzOiB1YnVudHU9MTAuMTAKUmFuazogMQpleHBsb2l0LWRiOiAxNTkxNgpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W04vQV0ke3R4dHJzdH0gY2Fwc190b19yb290IDIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4zNCx2ZXI8PTIuNi4zNgpUYWdzOiB1YnVudHU9MTAuMTAKUmFuazogMQpleHBsb2l0LWRiOiAxNTk0NApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEwLTQzNDddJHt0eHRyc3R9IGFtZXJpY2FuLXNpZ24tbGFuZ3VhZ2UKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4wLHZlcjw9Mi42LjM2ClRhZ3M6ClJhbms6IDEKZXhwbG9pdC1kYjogMTU3NzQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMC0zNDM3XSR7dHh0cnN0fSBwa3RjZHZkClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMCx2ZXI8PTIuNi4zNgpUYWdzOiB1YnVudHU9MTAuMDQKUmFuazogMQpleHBsb2l0LWRiOiAxNTE1MApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEwLTMwODFdJHt0eHRyc3R9IHZpZGVvNGxpbnV4ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMCx2ZXI8PTIuNi4zMwpUYWdzOiBSSEVMPTUKUmFuazogMQpleHBsb2l0LWRiOiAxNTAyNApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEyLTAwNTZdJHt0eHRyc3R9IG1lbW9kaXBwZXIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMC4wLHZlcjw9My4xLjAKVGFnczogdWJ1bnR1PSgxMC4wNHwxMS4xMCl7a2VybmVsOjMuMC4wLTEyLShnZW5lcmljfHNlcnZlcil9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdC56eDJjNC5jb20vQ1ZFLTIwMTItMDA1Ni9hYm91dC8Kc3JjLXVybDogaHR0cHM6Ly9naXQuengyYzQuY29tL0NWRS0yMDEyLTAwNTYvcGxhaW4vbWVtcG9kaXBwZXIuYwpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2MzEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9tZW1vZGlwcGVyCmJpbi11cmw6IGh0dHBzOi8vd2ViLmFyY2hpdmUub3JnL3dlYi8yMDE2MDYwMjE5MjYzMS9odHRwczovL3d3dy5rZXJuZWwtZXhwbG9pdHMuY29tL21lZGlhL21lbW9kaXBwZXI2NApleHBsb2l0LWRiOiAxODQxMQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEyLTAwNTYsQ1ZFLTIwMTAtMzg0OSxDVkUtMjAxMC0zODUwXSR7dHh0cnN0fSBmdWxsLW5lbHNvbgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjAsdmVyPD0yLjYuMzYKVGFnczogdWJ1bnR1PSg5LjEwfDEwLjEwKXtrZXJuZWw6Mi42LigzMXwzNSktKDE0fDE5KS0oc2VydmVyfGdlbmVyaWMpfSx1YnVudHU9MTAuMDR7a2VybmVsOjIuNi4zMi0oMjF8MjQpLXNlcnZlcn0KUmFuazogMQpzcmMtdXJsOiBodHRwOi8vdnVsbmZhY3Rvcnkub3JnL2V4cGxvaXRzL2Z1bGwtbmVsc29uLmMKYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTYwNjAyMTkyNjMxL2h0dHBzOi8vd3d3Lmtlcm5lbC1leHBsb2l0cy5jb20vbWVkaWEvZnVsbC1uZWxzb24KYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTYwNjAyMTkyNjMxL2h0dHBzOi8vd3d3Lmtlcm5lbC1leHBsb2l0cy5jb20vbWVkaWEvZnVsbC1uZWxzb242NApleHBsb2l0LWRiOiAxNTcwNApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEzLTE4NThdJHt0eHRyc3R9IENMT05FX05FV1VTRVJ8Q0xPTkVfRlMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI9My44LENPTkZJR19VU0VSX05TPXkKVGFnczogClJhbms6IDEKc3JjLXVybDogaHR0cDovL3N0ZWFsdGgub3BlbndhbGwubmV0L3hTcG9ydHMvY2xvd24tbmV3dXNlci5jCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9sd24ubmV0L0FydGljbGVzLzU0MzI3My8KZXhwbG9pdC1kYjogMzgzOTAKYXV0aG9yOiBTZWJhc3RpYW4gS3JhaG1lcgpDb21tZW50czogQ09ORklHX1VTRVJfTlMgbmVlZHMgdG8gYmUgZW5hYmxlZCAKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMy0yMDk0XSR7dHh0cnN0fSBwZXJmX3N3ZXZlbnQKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4zMix2ZXI8My44LjkseDg2XzY0ClRhZ3M6IFJIRUw9Nix1YnVudHU9MTIuMDR7a2VybmVsOjMuMi4wLSgyM3wyOSktZ2VuZXJpY30sZmVkb3JhPTE2e2tlcm5lbDozLjEuMC03LmZjMTYueDg2XzY0fSxmZWRvcmE9MTd7a2VybmVsOjMuMy40LTUuZmMxNy54ODZfNjR9LGRlYmlhbj03e2tlcm5lbDozLjIuMC00LWFtZDY0fQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3RpbWV0b2JsZWVkLmNvbS9hLWNsb3Nlci1sb29rLWF0LWEtcmVjZW50LXByaXZpbGVnZS1lc2NhbGF0aW9uLWJ1Zy1pbi1saW51eC1jdmUtMjAxMy0yMDk0LwpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2MzEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9wZXJmX3N3ZXZlbnQKYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTYwNjAyMTkyNjMxL2h0dHBzOi8vd3d3Lmtlcm5lbC1leHBsb2l0cy5jb20vbWVkaWEvcGVyZl9zd2V2ZW50NjQKZXhwbG9pdC1kYjogMjYxMzEKYXV0aG9yOiBBbmRyZWEgJ3NvcmJvJyBCaXR0YXUKQ29tbWVudHM6IE5vIFNNRVAvU01BUCBieXBhc3MKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMy0yMDk0XSR7dHh0cnN0fSBwZXJmX3N3ZXZlbnQgMgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjMyLHZlcjwzLjguOSx4ODZfNjQKVGFnczogdWJ1bnR1PTEyLjA0e2tlcm5lbDozLigyfDUpLjAtKDIzfDI5KS1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3RpbWV0b2JsZWVkLmNvbS9hLWNsb3Nlci1sb29rLWF0LWEtcmVjZW50LXByaXZpbGVnZS1lc2NhbGF0aW9uLWJ1Zy1pbi1saW51eC1jdmUtMjAxMy0yMDk0LwpzcmMtdXJsOiBodHRwczovL2N5c2VjbGFicy5jb20vZXhwbG9pdHMvdm5pa192MS5jCmV4cGxvaXQtZGI6IDMzNTg5CmF1dGhvcjogVml0YWx5ICd2bmlrJyBOaWtvbGVua28KQ29tbWVudHM6IE5vIFNNRVAvU01BUCBieXBhc3MKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMy0wMjY4XSR7dHh0cnN0fSBtc3IKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xOCx2ZXI8My43LjYKVGFnczogClJhbms6IDEKZXhwbG9pdC1kYjogMjcyOTcKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMy0xOTU5XSR7dHh0cnN0fSB1c2VybnNfcm9vdF9zcGxvaXQKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMC4xLHZlcjwzLjguOQpUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDEzLzA0LzI5LzEKZXhwbG9pdC1kYjogMjU0NTAKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMy0yMDk0XSR7dHh0cnN0fSBzZW10ZXgKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4zMix2ZXI8My44LjkKVGFnczogUkhFTD02ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vdGltZXRvYmxlZWQuY29tL2EtY2xvc2VyLWxvb2stYXQtYS1yZWNlbnQtcHJpdmlsZWdlLWVzY2FsYXRpb24tYnVnLWluLWxpbnV4LWN2ZS0yMDEzLTIwOTQvCmV4cGxvaXQtZGI6IDI1NDQ0CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTQtMDAzOF0ke3R4dHJzdH0gdGltZW91dHB3bgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49My40LjAsdmVyPD0zLjEzLjEsQ09ORklHX1g4Nl9YMzI9eQpUYWdzOiB1YnVudHU9MTMuMTAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9ibG9nLmluY2x1ZGVzZWN1cml0eS5jb20vMjAxNC8wMy9leHBsb2l0LUNWRS0yMDE0LTAwMzgteDMyLXJlY3ZtbXNnLWtlcm5lbC12dWxuZXJhYmxpdHkuaHRtbApiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2MzEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS90aW1lb3V0cHduNjQKZXhwbG9pdC1kYjogMzEzNDYKQ29tbWVudHM6IENPTkZJR19YODZfWDMyIG5lZWRzIHRvIGJlIGVuYWJsZWQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNC0wMDM4XSR7dHh0cnN0fSB0aW1lb3V0cHduIDIKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuNC4wLHZlcjw9My4xMy4xLENPTkZJR19YODZfWDMyPXkKVGFnczogdWJ1bnR1PSgxMy4wNHwxMy4xMCl7a2VybmVsOjMuKDh8MTEpLjAtKDEyfDE1fDE5KS1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL2Jsb2cuaW5jbHVkZXNlY3VyaXR5LmNvbS8yMDE0LzAzL2V4cGxvaXQtQ1ZFLTIwMTQtMDAzOC14MzItcmVjdm1tc2cta2VybmVsLXZ1bG5lcmFibGl0eS5odG1sCmV4cGxvaXQtZGI6IDMxMzQ3CkNvbW1lbnRzOiBDT05GSUdfWDg2X1gzMiBuZWVkcyB0byBiZSBlbmFibGVkCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTQtMDE5Nl0ke3R4dHJzdH0gcmF3bW9kZVBUWQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjMxLHZlcjw9My4xNC4zClRhZ3M6ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vYmxvZy5pbmNsdWRlc2VjdXJpdHkuY29tLzIwMTQvMDYvZXhwbG9pdC13YWxrdGhyb3VnaC1jdmUtMjAxNC0wMTk2LXB0eS1rZXJuZWwtcmFjZS1jb25kaXRpb24uaHRtbApleHBsb2l0LWRiOiAzMzUxNgpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE0LTI4NTFdJHt0eHRyc3R9IHVzZS1hZnRlci1mcmVlIGluIHBpbmdfaW5pdF9zb2NrKCkgJHtibGRibHV9KERvUykke3R4dHJzdH0KUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMC4xLHZlcjw9My4xNApUYWdzOiAKUmFuazogMAphbmFseXNpcy11cmw6IGh0dHBzOi8vY3lzZWNsYWJzLmNvbS9wYWdlP249MDIwMTIwMTYKZXhwbG9pdC1kYjogMzI5MjYKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNC00MDE0XSR7dHh0cnN0fSBpbm9kZV9jYXBhYmxlClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjAuMSx2ZXI8PTMuMTMKVGFnczogdWJ1bnR1PTEyLjA0ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNC8wNi8xMC80CmV4cGxvaXQtZGI6IDMzODI0CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTQtNDY5OV0ke3R4dHJzdH0gcHRyYWNlL3N5c3JldApSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49My4wLjEsdmVyPD0zLjgKVGFnczogdWJ1bnR1PTEyLjA0ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNC8wNy8wOC8xNgpleHBsb2l0LWRiOiAzNDEzNApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE0LTQ5NDNdJHt0eHRyc3R9IFBQUG9MMlRQICR7YmxkYmx1fShEb1MpJHt0eHRyc3R9ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjIsdmVyPD0zLjE1LjYKVGFnczogClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2N5c2VjbGFicy5jb20vcGFnZT9uPTAxMTAyMDE1CmV4cGxvaXQtZGI6IDM2MjY3CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTQtNTIwN10ke3R4dHJzdH0gZnVzZV9zdWlkClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjAuMSx2ZXI8PTMuMTYuMQpUYWdzOiAKUmFuazogMQpleHBsb2l0LWRiOiAzNDkyMwpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE1LTkzMjJdJHt0eHRyc3R9IEJhZElSRVQKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMC4xLHZlcjwzLjE3LjUseDg2XzY0ClRhZ3M6IFJIRUw8PTcsZmVkb3JhPTIwClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vbGFicy5icm9taXVtLmNvbS8yMDE1LzAyLzAyL2V4cGxvaXRpbmctYmFkaXJldC12dWxuZXJhYmlsaXR5LWN2ZS0yMDE0LTkzMjItbGludXgta2VybmVsLXByaXZpbGVnZS1lc2NhbGF0aW9uLwpzcmMtdXJsOiBodHRwOi8vc2l0ZS5waTMuY29tLnBsL2V4cC9wX2N2ZS0yMDE0LTkzMjIudGFyLmd6CmV4cGxvaXQtZGI6CmF1dGhvcjogUmFmYWwgJ24zcmdhbCcgV29qdGN6dWsgJiBBZGFtICdwaTMnIFphYnJvY2tpCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTUtMzI5MF0ke3R4dHJzdH0gZXNwZml4NjRfTk1JClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjEzLHZlcjw0LjEuNix4ODZfNjQKVGFnczogClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNS8wOC8wNC84CmV4cGxvaXQtZGI6IDM3NzIyCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bTi9BXSR7dHh0cnN0fSBibHVldG9vdGgKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI8PTIuNi4xMQpUYWdzOgpSYW5rOiAxCmV4cGxvaXQtZGI6IDQ3NTYKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS0xMzI4XSR7dHh0cnN0fSBvdmVybGF5ZnMKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMTMuMCx2ZXI8PTMuMTkuMApUYWdzOiB1YnVudHU9KDEyLjA0fDE0LjA0KXtrZXJuZWw6My4xMy4wLSgyfDN8NHw1KSotZ2VuZXJpY30sdWJ1bnR1PSgxNC4xMHwxNS4wNCl7a2VybmVsOjMuKDEzfDE2KS4wLSotZ2VuZXJpY30KUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9zZWNsaXN0cy5vcmcvb3NzLXNlYy8yMDE1L3EyLzcxNwpiaW4tdXJsOiBodHRwczovL3dlYi5hcmNoaXZlLm9yZy93ZWIvMjAxNjA2MDIxOTI2MzEvaHR0cHM6Ly93d3cua2VybmVsLWV4cGxvaXRzLmNvbS9tZWRpYS9vZnNfMzIKYmluLXVybDogaHR0cHM6Ly93ZWIuYXJjaGl2ZS5vcmcvd2ViLzIwMTYwNjAyMTkyNjMxL2h0dHBzOi8vd3d3Lmtlcm5lbC1leHBsb2l0cy5jb20vbWVkaWEvb2ZzXzY0CmV4cGxvaXQtZGI6IDM3MjkyCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTUtODY2MF0ke3R4dHJzdH0gb3ZlcmxheWZzIChvdmxfc2V0YXR0cikKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMC4wLHZlcjw9NC4zLjMKVGFnczoKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly93d3cuaGFsZmRvZy5uZXQvU2VjdXJpdHkvMjAxNS9Vc2VyTmFtZXNwYWNlT3ZlcmxheWZzU2V0dWlkV3JpdGVFeGVjLwpleHBsb2l0LWRiOiAzOTIzMApFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE1LTg2NjBdJHt0eHRyc3R9IG92ZXJsYXlmcyAob3ZsX3NldGF0dHIpClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjAuMCx2ZXI8PTQuMy4zClRhZ3M6IHVidW50dT0oMTQuMDR8MTUuMTApe2tlcm5lbDo0LjIuMC0oMTh8MTl8MjB8MjF8MjIpLWdlbmVyaWN9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3LmhhbGZkb2cubmV0L1NlY3VyaXR5LzIwMTUvVXNlck5hbWVzcGFjZU92ZXJsYXlmc1NldHVpZFdyaXRlRXhlYy8KZXhwbG9pdC1kYjogMzkxNjYKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi0wNzI4XSR7dHh0cnN0fSBrZXlyaW5nClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjEwLHZlcjw0LjQuMQpUYWdzOgpSYW5rOiAwCmFuYWx5c2lzLXVybDogaHR0cDovL3BlcmNlcHRpb24tcG9pbnQuaW8vMjAxNi8wMS8xNC9hbmFseXNpcy1hbmQtZXhwbG9pdGF0aW9uLW9mLWEtbGludXgta2VybmVsLXZ1bG5lcmFiaWxpdHktY3ZlLTIwMTYtMDcyOC8KZXhwbG9pdC1kYjogNDAwMDMKQ29tbWVudHM6IEV4cGxvaXQgdGFrZXMgYWJvdXQgfjMwIG1pbnV0ZXMgdG8gcnVuLiBFeHBsb2l0IGlzIG5vdCByZWxpYWJsZSwgc2VlOiBodHRwczovL2N5c2VjbGFicy5jb20vYmxvZy9jdmUtMjAxNi0wNzI4LXBvYy1ub3Qtd29ya2luZwpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE2LTIzODRdJHt0eHRyc3R9IHVzYi1taWRpClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjAuMCx2ZXI8PTQuNC44ClRhZ3M6IHVidW50dT0xNC4wNCxmZWRvcmE9MjIKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8veGFpcnkuZ2l0aHViLmlvL2Jsb2cvMjAxNi9jdmUtMjAxNi0yMzg0CnNyYy11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS94YWlyeS9rZXJuZWwtZXhwbG9pdHMvbWFzdGVyL0NWRS0yMDE2LTIzODQvcG9jLmMKZXhwbG9pdC1kYjogNDE5OTkKQ29tbWVudHM6IFJlcXVpcmVzIGFiaWxpdHkgdG8gcGx1ZyBpbiBhIG1hbGljaW91cyBVU0IgZGV2aWNlIGFuZCB0byBleGVjdXRlIGEgbWFsaWNpb3VzIGJpbmFyeSBhcyBhIG5vbi1wcml2aWxlZ2VkIHVzZXIKYXV0aG9yOiBBbmRyZXkgJ3hhaXJ5JyBLb25vdmFsb3YKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi00OTk3XSR7dHh0cnN0fSB0YXJnZXRfb2Zmc2V0ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj00LjQuMCx2ZXI8PTQuNC4wLGNtZDpncmVwIC1xaSBpcF90YWJsZXMgL3Byb2MvbW9kdWxlcwpUYWdzOiB1YnVudHU9MTYuMDR7a2VybmVsOjQuNC4wLTIxLWdlbmVyaWN9ClJhbms6IDEKc3JjLXVybDogaHR0cHM6Ly9naXRsYWIuY29tL2V4cGxvaXQtZGF0YWJhc2UvZXhwbG9pdGRiLWJpbi1zcGxvaXRzLy0vcmF3L21haW4vYmluLXNwbG9pdHMvNDAwNTMuemlwCkNvbW1lbnRzOiBpcF90YWJsZXMua28gbmVlZHMgdG8gYmUgbG9hZGVkCmV4cGxvaXQtZGI6IDQwMDQ5CmF1dGhvcjogVml0YWx5ICd2bmlrJyBOaWtvbGVua28KRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi00NTU3XSR7dHh0cnN0fSBkb3VibGUtZmRwdXQoKQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49NC40LHZlcjw0LjUuNSxDT05GSUdfQlBGX1NZU0NBTEw9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF9icGZfZGlzYWJsZWQhPTEKVGFnczogdWJ1bnR1PTE2LjA0e2tlcm5lbDo0LjQuMC0yMS1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9idWdzLmNocm9taXVtLm9yZy9wL3Byb2plY3QtemVyby9pc3N1ZXMvZGV0YWlsP2lkPTgwOApzcmMtdXJsOiBodHRwczovL2dpdGxhYi5jb20vZXhwbG9pdC1kYXRhYmFzZS9leHBsb2l0ZGItYmluLXNwbG9pdHMvLS9yYXcvbWFpbi9iaW4tc3Bsb2l0cy8zOTc3Mi56aXAKQ29tbWVudHM6IENPTkZJR19CUEZfU1lTQ0FMTCBuZWVkcyB0byBiZSBzZXQgJiYga2VybmVsLnVucHJpdmlsZWdlZF9icGZfZGlzYWJsZWQgIT0gMQpleHBsb2l0LWRiOiA0MDc1OQphdXRob3I6IEphbm4gSG9ybgpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE2LTUxOTVdJHt0eHRyc3R9IGRpcnR5Y293ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0yLjYuMjIsdmVyPD00LjguMwpUYWdzOiBkZWJpYW49N3w4LFJIRUw9NXtrZXJuZWw6Mi42LigxOHwyNHwzMyktKn0sUkhFTD02e2tlcm5lbDoyLjYuMzItKnwzLigwfDJ8Nnw4fDEwKS4qfDIuNi4zMy45LXJ0MzF9LFJIRUw9N3trZXJuZWw6My4xMC4wLSp8NC4yLjAtMC4yMS5lbDd9LHVidW50dT0xNi4wNHwxNC4wNHwxMi4wNApSYW5rOiA0CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL2RpcnR5Y293L2RpcnR5Y293LmdpdGh1Yi5pby93aWtpL1Z1bG5lcmFiaWxpdHlEZXRhaWxzCkNvbW1lbnRzOiBGb3IgUkhFTC9DZW50T1Mgc2VlIGV4YWN0IHZ1bG5lcmFibGUgdmVyc2lvbnMgaGVyZTogaHR0cHM6Ly9hY2Nlc3MucmVkaGF0LmNvbS9zaXRlcy9kZWZhdWx0L2ZpbGVzL3JoLWN2ZS0yMDE2LTUxOTVfNS5zaApleHBsb2l0LWRiOiA0MDYxMQphdXRob3I6IFBoaWwgT2VzdGVyCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTYtNTE5NV0ke3R4dHJzdH0gZGlydHljb3cgMgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49Mi42LjIyLHZlcjw9NC44LjMKVGFnczogZGViaWFuPTd8OCxSSEVMPTV8Nnw3LHVidW50dT0xNC4wNHwxMi4wNCx1YnVudHU9MTAuMDR7a2VybmVsOjIuNi4zMi0yMS1nZW5lcmljfSx1YnVudHU9MTYuMDR7a2VybmVsOjQuNC4wLTIxLWdlbmVyaWN9ClJhbms6IDQKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vZGlydHljb3cvZGlydHljb3cuZ2l0aHViLmlvL3dpa2kvVnVsbmVyYWJpbGl0eURldGFpbHMKZXh0LXVybDogaHR0cHM6Ly93d3cuZXhwbG9pdC1kYi5jb20vZG93bmxvYWQvNDA4NDcKQ29tbWVudHM6IEZvciBSSEVML0NlbnRPUyBzZWUgZXhhY3QgdnVsbmVyYWJsZSB2ZXJzaW9ucyBoZXJlOiBodHRwczovL2FjY2Vzcy5yZWRoYXQuY29tL3NpdGVzL2RlZmF1bHQvZmlsZXMvcmgtY3ZlLTIwMTYtNTE5NV81LnNoCmV4cGxvaXQtZGI6IDQwODM5CmF1dGhvcjogRmlyZUZhcnQgKGF1dGhvciBvZiBleHBsb2l0IGF0IEVEQiA0MDgzOSk7IEdhYnJpZWxlIEJvbmFjaW5pIChhdXRob3Igb2YgZXhwbG9pdCBhdCAnZXh0LXVybCcpCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTYtODY1NV0ke3R4dHJzdH0gY2hvY29ib19yb290ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj00LjQuMCx2ZXI8NC45LENPTkZJR19VU0VSX05TPXksc3lzY3RsOmtlcm5lbC51bnByaXZpbGVnZWRfdXNlcm5zX2Nsb25lPT0xClRhZ3M6IHVidW50dT0oMTQuMDR8MTYuMDQpe2tlcm5lbDo0LjQuMC0oMjF8MjJ8MjR8Mjh8MzF8MzR8MzZ8Mzh8NDJ8NDN8NDV8NDd8NTEpLWdlbmVyaWN9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNi8xMi8wNi8xCkNvbW1lbnRzOiBDQVBfTkVUX1JBVyBjYXBhYmlsaXR5IGlzIG5lZWRlZCBPUiBDT05GSUdfVVNFUl9OUz15IG5lZWRzIHRvIGJlIGVuYWJsZWQKYmluLXVybDogaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3JhcGlkNy9tZXRhc3Bsb2l0LWZyYW1ld29yay9tYXN0ZXIvZGF0YS9leHBsb2l0cy9DVkUtMjAxNi04NjU1L2Nob2NvYm9fcm9vdApleHBsb2l0LWRiOiA0MDg3MQphdXRob3I6IHJlYmVsCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTYtOTc5M10ke3R4dHJzdH0gU09fe1NORHxSQ1Z9QlVGRk9SQ0UKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTMuMTEsdmVyPDQuOC4xNCxDT05GSUdfVVNFUl9OUz15LHN5c2N0bDprZXJuZWwudW5wcml2aWxlZ2VkX3VzZXJuc19jbG9uZT09MQpUYWdzOgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL3hhaXJ5L2tlcm5lbC1leHBsb2l0cy90cmVlL21hc3Rlci9DVkUtMjAxNi05NzkzCnNyYy11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS94YWlyeS9rZXJuZWwtZXhwbG9pdHMvbWFzdGVyL0NWRS0yMDE2LTk3OTMvcG9jLmMKQ29tbWVudHM6IENBUF9ORVRfQURNSU4gY2FwcyBPUiBDT05GSUdfVVNFUl9OUz15IG5lZWRlZC4gTm8gU01FUC9TTUFQL0tBU0xSIGJ5cGFzcyBpbmNsdWRlZC4gVGVzdGVkIGluIFFFTVUgb25seQpleHBsb2l0LWRiOiA0MTk5NQphdXRob3I6IEFuZHJleSAneGFpcnknIEtvbm92YWxvdgpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE3LTYwNzRdJHt0eHRyc3R9IGRjY3AKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xOCx2ZXI8PTQuOS4xMSxDT05GSUdfSVBfRENDUD1bbXldClRhZ3M6IHVidW50dT0oMTQuMDR8MTYuMDQpe2tlcm5lbDo0LjQuMC02Mi1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3d3dy5vcGVud2FsbC5jb20vbGlzdHMvb3NzLXNlY3VyaXR5LzIwMTcvMDIvMjIvMwpDb21tZW50czogUmVxdWlyZXMgS2VybmVsIGJlIGJ1aWx0IHdpdGggQ09ORklHX0lQX0RDQ1AgZW5hYmxlZC4gSW5jbHVkZXMgcGFydGlhbCBTTUVQL1NNQVAgYnlwYXNzCmV4cGxvaXQtZGI6IDQxNDU4CmF1dGhvcjogQW5kcmV5ICd4YWlyeScgS29ub3ZhbG92CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctNzMwOF0ke3R4dHJzdH0gYWZfcGFja2V0ClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjIsdmVyPD00LjEwLjYsQ09ORklHX1VTRVJfTlM9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEKVGFnczogdWJ1bnR1PTE2LjA0e2tlcm5lbDo0LjguMC0oMzR8MzZ8Mzl8NDF8NDJ8NDR8NDUpLWdlbmVyaWN9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2dvb2dsZXByb2plY3R6ZXJvLmJsb2dzcG90LmNvbS8yMDE3LzA1L2V4cGxvaXRpbmctbGludXgta2VybmVsLXZpYS1wYWNrZXQuaHRtbApzcmMtdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20veGFpcnkva2VybmVsLWV4cGxvaXRzL21hc3Rlci9DVkUtMjAxNy03MzA4L3BvYy5jCmV4dC11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9iY29sZXMva2VybmVsLWV4cGxvaXRzL21hc3Rlci9DVkUtMjAxNy03MzA4L3BvYy5jCkNvbW1lbnRzOiBDQVBfTkVUX1JBVyBjYXAgb3IgQ09ORklHX1VTRVJfTlM9eSBuZWVkZWQuIE1vZGlmaWVkIHZlcnNpb24gYXQgJ2V4dC11cmwnIGFkZHMgc3VwcG9ydCBmb3IgYWRkaXRpb25hbCBrZXJuZWxzCmJpbi11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9yYXBpZDcvbWV0YXNwbG9pdC1mcmFtZXdvcmsvbWFzdGVyL2RhdGEvZXhwbG9pdHMvY3ZlLTIwMTctNzMwOC9leHBsb2l0CmV4cGxvaXQtZGI6IDQxOTk0CmF1dGhvcjogQW5kcmV5ICd4YWlyeScgS29ub3ZhbG92IChvcmdpbmFsIGV4cGxvaXQgYXV0aG9yKTsgQnJlbmRhbiBDb2xlcyAoYXV0aG9yIG9mIGV4cGxvaXQgdXBkYXRlIGF0ICdleHQtdXJsJykKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNy0xNjk5NV0ke3R4dHJzdH0gZUJQRl92ZXJpZmllcgpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49NC40LHZlcjw9NC4xNC44LENPTkZJR19CUEZfU1lTQ0FMTD15LHN5c2N0bDprZXJuZWwudW5wcml2aWxlZ2VkX2JwZl9kaXNhYmxlZCE9MQpUYWdzOiBkZWJpYW49OS4we2tlcm5lbDo0LjkuMC0zLWFtZDY0fSxmZWRvcmE9MjV8MjZ8MjcsdWJ1bnR1PTE0LjA0e2tlcm5lbDo0LjQuMC04OS1nZW5lcmljfSx1YnVudHU9KDE2LjA0fDE3LjA0KXtrZXJuZWw6NC4oOHwxMCkuMC0oMTl8Mjh8NDUpLWdlbmVyaWN9ClJhbms6IDUKYW5hbHlzaXMtdXJsOiBodHRwczovL3JpY2tsYXJhYmVlLmJsb2dzcG90LmNvbS8yMDE4LzA3L2VicGYtYW5kLWFuYWx5c2lzLW9mLWdldC1yZWt0LWxpbnV4Lmh0bWwKQ29tbWVudHM6IENPTkZJR19CUEZfU1lTQ0FMTCBuZWVkcyB0byBiZSBzZXQgJiYga2VybmVsLnVucHJpdmlsZWdlZF9icGZfZGlzYWJsZWQgIT0gMQpiaW4tdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vcmFwaWQ3L21ldGFzcGxvaXQtZnJhbWV3b3JrL21hc3Rlci9kYXRhL2V4cGxvaXRzL2N2ZS0yMDE3LTE2OTk1L2V4cGxvaXQub3V0CmV4cGxvaXQtZGI6IDQ1MDEwCmF1dGhvcjogUmljayBMYXJhYmVlCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMTAwMDExMl0ke3R4dHJzdH0gTkVUSUZfRl9VRk8KUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTQuNCx2ZXI8PTQuMTMsQ09ORklHX1VTRVJfTlM9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEKVGFnczogdWJ1bnR1PTE0LjA0e2tlcm5lbDo0LjQuMC0qfSx1YnVudHU9MTYuMDR7a2VybmVsOjQuOC4wLSp9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNy8wOC8xMy8xCnNyYy11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS94YWlyeS9rZXJuZWwtZXhwbG9pdHMvbWFzdGVyL0NWRS0yMDE3LTEwMDAxMTIvcG9jLmMKZXh0LXVybDogaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2Jjb2xlcy9rZXJuZWwtZXhwbG9pdHMvbWFzdGVyL0NWRS0yMDE3LTEwMDAxMTIvcG9jLmMKQ29tbWVudHM6IENBUF9ORVRfQURNSU4gY2FwIG9yIENPTkZJR19VU0VSX05TPXkgbmVlZGVkLiBTTUVQL0tBU0xSIGJ5cGFzcyBpbmNsdWRlZC4gTW9kaWZpZWQgdmVyc2lvbiBhdCAnZXh0LXVybCcgYWRkcyBzdXBwb3J0IGZvciBhZGRpdGlvbmFsIGRpc3Ryb3Mva2VybmVscwpiaW4tdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vcmFwaWQ3L21ldGFzcGxvaXQtZnJhbWV3b3JrL21hc3Rlci9kYXRhL2V4cGxvaXRzL2N2ZS0yMDE3LTEwMDAxMTIvZXhwbG9pdC5vdXQKZXhwbG9pdC1kYjoKYXV0aG9yOiBBbmRyZXkgJ3hhaXJ5JyBLb25vdmFsb3YgKG9yZ2luYWwgZXhwbG9pdCBhdXRob3IpOyBCcmVuZGFuIENvbGVzIChhdXRob3Igb2YgZXhwbG9pdCB1cGRhdGUgYXQgJ2V4dC11cmwnKQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE3LTEwMDAyNTNdJHt0eHRyc3R9IFBJRV9zdGFja19jb3JydXB0aW9uClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjIsdmVyPD00LjEzLHg4Nl82NApUYWdzOiBSSEVMPTYsUkhFTD03e2tlcm5lbDozLjEwLjAtNTE0LjIxLjJ8My4xMC4wLTUxNC4yNi4xfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cucXVhbHlzLmNvbS8yMDE3LzA5LzI2L2xpbnV4LXBpZS1jdmUtMjAxNy0xMDAwMjUzL2N2ZS0yMDE3LTEwMDAyNTMudHh0CnNyYy11cmw6IGh0dHBzOi8vd3d3LnF1YWx5cy5jb20vMjAxNy8wOS8yNi9saW51eC1waWUtY3ZlLTIwMTctMTAwMDI1My9jdmUtMjAxNy0xMDAwMjUzLmMKZXhwbG9pdC1kYjogNDI4ODcKYXV0aG9yOiBRdWFseXMKQ29tbWVudHM6CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTgtNTMzM10ke3R4dHJzdH0gcmRzX2F0b21pY19mcmVlX29wIE5VTEwgcG9pbnRlciBkZXJlZmVyZW5jZQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcj49NC40LHZlcjw9NC4xNC4xMyxjbWQ6Z3JlcCAtcWkgcmRzIC9wcm9jL21vZHVsZXMseDg2XzY0ClRhZ3M6IHVidW50dT0xNi4wNHtrZXJuZWw6NC40LjB8NC44LjB9ClJhbms6IDEKc3JjLXVybDogaHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS93Ym93bGluZy85ZDMyNDkyYmQ5NmQ5ZTdjM2JmNTJlMjNhMGFjMzBhNC9yYXcvOTU5MzI1ODE5Yzc4MjQ4YTY0MzcxMDJiYjI4OWJiODU3OGExMzVjZC9jdmUtMjAxOC01MzMzLXBvYy5jCmV4dC11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9iY29sZXMva2VybmVsLWV4cGxvaXRzL21hc3Rlci9DVkUtMjAxOC01MzMzL2N2ZS0yMDE4LTUzMzMuYwpDb21tZW50czogcmRzLmtvIGtlcm5lbCBtb2R1bGUgbmVlZHMgdG8gYmUgbG9hZGVkLiBNb2RpZmllZCB2ZXJzaW9uIGF0ICdleHQtdXJsJyBhZGRzIHN1cHBvcnQgZm9yIGFkZGl0aW9uYWwgdGFyZ2V0cyBhbmQgYnlwYXNzaW5nIEtBU0xSLgphdXRob3I6IHdib3dsaW5nIChvcmdpbmFsIGV4cGxvaXQgYXV0aG9yKTsgYmNvbGVzIChhdXRob3Igb2YgZXhwbG9pdCB1cGRhdGUgYXQgJ2V4dC11cmwnKQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE4LTE4OTU1XSR7dHh0cnN0fSBzdWJ1aWRfc2hlbGwKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTQuMTUsdmVyPD00LjE5LjIsQ09ORklHX1VTRVJfTlM9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEsY21kOlsgLXUgL3Vzci9iaW4vbmV3dWlkbWFwIF0sY21kOlsgLXUgL3Vzci9iaW4vbmV3Z2lkbWFwIF0KVGFnczogdWJ1bnR1PTE4LjA0e2tlcm5lbDo0LjE1LjAtMjAtZ2VuZXJpY30sZmVkb3JhPTI4e2tlcm5lbDo0LjE2LjMtMzAxLmZjMjh9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2J1Z3MuY2hyb21pdW0ub3JnL3AvcHJvamVjdC16ZXJvL2lzc3Vlcy9kZXRhaWw/aWQ9MTcxMgpzcmMtdXJsOiBodHRwczovL2dpdGxhYi5jb20vZXhwbG9pdC1kYXRhYmFzZS9leHBsb2l0ZGItYmluLXNwbG9pdHMvLS9yYXcvbWFpbi9iaW4tc3Bsb2l0cy80NTg4Ni56aXAKZXhwbG9pdC1kYjogNDU4ODYKYXV0aG9yOiBKYW5uIEhvcm4KQ29tbWVudHM6IENPTkZJR19VU0VSX05TIG5lZWRzIHRvIGJlIGVuYWJsZWQKRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOS0xMzI3Ml0ke3R4dHJzdH0gUFRSQUNFX1RSQUNFTUUKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTQsdmVyPDUuMS4xNyxzeXNjdGw6a2VybmVsLnlhbWEucHRyYWNlX3Njb3BlPT0wLHg4Nl82NApUYWdzOiB1YnVudHU9MTYuMDR7a2VybmVsOjQuMTUuMC0qfSx1YnVudHU9MTguMDR7a2VybmVsOjQuMTUuMC0qfSxkZWJpYW49OXtrZXJuZWw6NC45LjAtKn0sZGViaWFuPTEwe2tlcm5lbDo0LjE5LjAtKn0sZmVkb3JhPTMwe2tlcm5lbDo1LjAuOS0qfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9idWdzLmNocm9taXVtLm9yZy9wL3Byb2plY3QtemVyby9pc3N1ZXMvZGV0YWlsP2lkPTE5MDMKc3JjLXVybDogaHR0cHM6Ly9naXRsYWIuY29tL2V4cGxvaXQtZGF0YWJhc2UvZXhwbG9pdGRiLWJpbi1zcGxvaXRzLy0vcmF3L21haW4vYmluLXNwbG9pdHMvNDcxMzMuemlwCmV4dC11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9iY29sZXMva2VybmVsLWV4cGxvaXRzL21hc3Rlci9DVkUtMjAxOS0xMzI3Mi9wb2MuYwpDb21tZW50czogUmVxdWlyZXMgYW4gYWN0aXZlIFBvbEtpdCBhZ2VudC4KZXhwbG9pdC1kYjogNDcxMzMKZXhwbG9pdC1kYjogNDcxNjMKYXV0aG9yOiBKYW5uIEhvcm4gKG9yZ2luYWwgZXhwbG9pdCBhdXRob3IpOyBiY29sZXMgKGF1dGhvciBvZiBleHBsb2l0IHVwZGF0ZSBhdCAnZXh0LXVybCcpCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTktMTU2NjZdJHt0eHRyc3R9IFhGUk1fVUFGClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLHZlcjw1LjAuMTksQ09ORklHX1VTRVJfTlM9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEsQ09ORklHX1hGUk09eQpUYWdzOgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9kdWFzeW50LmNvbS9ibG9nL3VidW50dS1jZW50b3MtcmVkaGF0LXByaXZlc2MKYmluLXVybDogaHR0cHM6Ly9naXRodWIuY29tL2R1YXN5bnQveGZybV9wb2MvcmF3L21hc3Rlci9sdWNreTAKQ29tbWVudHM6IENPTkZJR19VU0VSX05TIG5lZWRzIHRvIGJlIGVuYWJsZWQ7IENPTkZJR19YRlJNIG5lZWRzIHRvIGJlIGVuYWJsZWQKYXV0aG9yOiBWaXRhbHkgJ3ZuaWsnIE5pa29sZW5rbwpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDIxLTI3MzY1XSR7dHh0cnN0fSBsaW51eC1pc2NzaQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcjw9NS4xMS4zLENPTkZJR19TTEFCX0ZSRUVMSVNUX0hBUkRFTkVEIT15ClRhZ3M6IFJIRUw9OApSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9ibG9nLmdyaW1tLWNvLmNvbS8yMDIxLzAzL25ldy1vbGQtYnVncy1pbi1saW51eC1rZXJuZWwuaHRtbApzcmMtdXJsOiBodHRwczovL2NvZGVsb2FkLmdpdGh1Yi5jb20vZ3JpbW0tY28vTm90UXVpdGUwRGF5RnJpZGF5L3ppcC90cnVuawpDb21tZW50czogQ09ORklHX1NMQUJfRlJFRUxJU1RfSEFSREVORUQgbXVzdCBub3QgYmUgZW5hYmxlZAphdXRob3I6IEdSSU1NCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMjEtMzQ5MF0ke3R4dHJzdH0gZUJQRiBBTFUzMiBib3VuZHMgdHJhY2tpbmcgZm9yIGJpdHdpc2Ugb3BzClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj01LjcsdmVyPDUuMTIsQ09ORklHX0JQRl9TWVNDQUxMPXksc3lzY3RsOmtlcm5lbC51bnByaXZpbGVnZWRfYnBmX2Rpc2FibGVkIT0xClRhZ3M6IHVidW50dT0yMC4wNHtrZXJuZWw6NS44LjAtKDI1fDI2fDI3fDI4fDI5fDMwfDMxfDMyfDMzfDM0fDM1fDM2fDM3fDM4fDM5fDQwfDQxfDQyfDQzfDQ0fDQ1fDQ2fDQ3fDQ4fDQ5fDUwfDUxfDUyKS0qfSx1YnVudHU9MjEuMDR7a2VybmVsOjUuMTEuMC0xNi0qfQpSYW5rOiA1CmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cuZ3JhcGxzZWN1cml0eS5jb20vcG9zdC9rZXJuZWwtcHduaW5nLXdpdGgtZWJwZi1hLWxvdmUtc3RvcnkKc3JjLXVybDogaHR0cHM6Ly9jb2RlbG9hZC5naXRodWIuY29tL2Nob21waWUxMzM3L0xpbnV4X0xQRV9lQlBGX0NWRS0yMDIxLTM0OTAvemlwL21haW4KQ29tbWVudHM6IENPTkZJR19CUEZfU1lTQ0FMTCBuZWVkcyB0byBiZSBzZXQgJiYga2VybmVsLnVucHJpdmlsZWdlZF9icGZfZGlzYWJsZWQgIT0gMQphdXRob3I6IGNob21waWUxMzM3CkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMjEtMjI1NTVdJHt0eHRyc3R9IE5ldGZpbHRlciBoZWFwIG91dC1vZi1ib3VuZHMgd3JpdGUKUmVxczogcGtnPWxpbnV4LWtlcm5lbCx2ZXI+PTIuNi4xOSx2ZXI8PTUuMTItcmM2ClRhZ3M6IHVidW50dT0yMC4wNHtrZXJuZWw6NS44LjAtKn0KUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ29vZ2xlLmdpdGh1Yi5pby9zZWN1cml0eS1yZXNlYXJjaC9wb2NzL2xpbnV4L2N2ZS0yMDIxLTIyNTU1L3dyaXRldXAuaHRtbApzcmMtdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vZ29vZ2xlL3NlY3VyaXR5LXJlc2VhcmNoL21hc3Rlci9wb2NzL2xpbnV4L2N2ZS0yMDIxLTIyNTU1L2V4cGxvaXQuYwpleHQtdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vYmNvbGVzL2tlcm5lbC1leHBsb2l0cy9tYXN0ZXIvQ1ZFLTIwMjEtMjI1NTUvZXhwbG9pdC5jCkNvbW1lbnRzOiBpcF90YWJsZXMga2VybmVsIG1vZHVsZSBtdXN0IGJlIGxvYWRlZApleHBsb2l0LWRiOiA1MDEzNQphdXRob3I6IHRoZWZsb3cgKG9yZ2luYWwgZXhwbG9pdCBhdXRob3IpOyBiY29sZXMgKGF1dGhvciBvZiBleHBsb2l0IHVwZGF0ZSBhdCAnZXh0LXVybCcpCkVPRgopCgpFWFBMT0lUU1soKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMjItMDg0N10ke3R4dHJzdH0gRGlydHlQaXBlClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj01LjgsdmVyPD01LjE2LjExClRhZ3M6IHVidW50dT0oMjAuMDR8MjEuMDQpLGRlYmlhbj0xMQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9kaXJ0eXBpcGUuY200YWxsLmNvbS8Kc3JjLXVybDogaHR0cHM6Ly9oYXh4LmluL2ZpbGVzL2RpcnR5cGlwZXouYwpleHBsb2l0LWRiOiA1MDgwOAphdXRob3I6IGJsYXN0eSAob3JpZ2luYWwgZXhwbG9pdCBhdXRob3I6IE1heCBLZWxsZXJtYW5uKQpFT0YKKQoKRVhQTE9JVFNbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDIyLTI1ODZdJHt0eHRyc3R9IG5mdF9vYmplY3QgVUFGClJlcXM6IHBrZz1saW51eC1rZXJuZWwsdmVyPj0zLjE2LENPTkZJR19VU0VSX05TPXksc3lzY3RsOmtlcm5lbC51bnByaXZpbGVnZWRfdXNlcm5zX2Nsb25lPT0xClRhZ3M6IHVidW50dT0oMjAuMDQpe2tlcm5lbDo1LjEyLjEzfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDIyLzA4LzI5LzUKc3JjLXVybDogaHR0cHM6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDIyLzA4LzI5LzUvMQpDb21tZW50czoga2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9MSByZXF1aXJlZCAodG8gb2J0YWluIENBUF9ORVRfQURNSU4pCmF1dGhvcjogdnVsbmVyYWJpbGl0eSBkaXNjb3Zlcnk6IFRlYW0gT3JjYSBvZiBTZWEgU2VjdXJpdHk7IEV4cGxvaXQgYXV0aG9yOiBBbGVqYW5kcm8gR3VlcnJlcm8KRU9GCikKCkVYUExPSVRTWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAyMi0zMjI1MF0ke3R4dHJzdH0gbmZ0X29iamVjdCBVQUYgKE5GVF9NU0dfTkVXU0VUKQpSZXFzOiBwa2c9bGludXgta2VybmVsLHZlcjw1LjE4LjEsQ09ORklHX1VTRVJfTlM9eSxzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEKVGFnczogdWJ1bnR1PSgyMi4wNCl7a2VybmVsOjUuMTUuMC0yNy1nZW5lcmljfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9yZXNlYXJjaC5uY2Nncm91cC5jb20vMjAyMi8wOS8wMS9zZXR0bGVycy1vZi1uZXRsaW5rLWV4cGxvaXRpbmctYS1saW1pdGVkLXVhZi1pbi1uZl90YWJsZXMtY3ZlLTIwMjItMzIyNTAvCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9ibG9nLnRoZW9yaS5pby9yZXNlYXJjaC9DVkUtMjAyMi0zMjI1MC1saW51eC1rZXJuZWwtbHBlLTIwMjIvCnNyYy11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS90aGVvcmktaW8vQ1ZFLTIwMjItMzIyNTAtZXhwbG9pdC9tYWluL2V4cC5jCkNvbW1lbnRzOiBrZXJuZWwudW5wcml2aWxlZ2VkX3VzZXJuc19jbG9uZT0xIHJlcXVpcmVkICh0byBvYnRhaW4gQ0FQX05FVF9BRE1JTikKYXV0aG9yOiB2dWxuZXJhYmlsaXR5IGRpc2NvdmVyeTogRURHIFRlYW0gZnJvbSBOQ0MgR3JvdXA7IEF1dGhvciBvZiB0aGlzIGV4cGxvaXQ6IHRoZW9yaS5pbwpFT0YKKQoKCiMjIyMjIyMjIyMjIyBVU0VSU1BBQ0UgRVhQTE9JVFMgIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjCm49MAoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwNC0wMTg2XSR7dHh0cnN0fSBzYW1iYQpSZXFzOiBwa2c9c2FtYmEsdmVyPD0yLjIuOApUYWdzOiAKUmFuazogMQpleHBsb2l0LWRiOiAyMzY3NApFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAwOS0xMTg1XSR7dHh0cnN0fSB1ZGV2ClJlcXM6IHBrZz11ZGV2LHZlcjwxNDEsY21kOltbIC1mIC9ldGMvdWRldi9ydWxlcy5kLzk1LXVkZXYtbGF0ZS5ydWxlcyB8fCAtZiAvbGliL3VkZXYvcnVsZXMuZC85NS11ZGV2LWxhdGUucnVsZXMgXV0KVGFnczogdWJ1bnR1PTguMTB8OS4wNApSYW5rOiAxCmV4cGxvaXQtZGI6IDg1NzIKQ29tbWVudHM6IFZlcnNpb248MS40LjEgdnVsbmVyYWJsZSBidXQgZGlzdHJvcyB1c2Ugb3duIHZlcnNpb25pbmcgc2NoZW1lLiBNYW51YWwgdmVyaWZpY2F0aW9uIG5lZWRlZCAKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMDktMTE4NV0ke3R4dHJzdH0gdWRldiAyClJlcXM6IHBrZz11ZGV2LHZlcjwxNDEKVGFnczoKUmFuazogMQpleHBsb2l0LWRiOiA4NDc4CkNvbW1lbnRzOiBTU0ggYWNjZXNzIHRvIG5vbiBwcml2aWxlZ2VkIHVzZXIgaXMgbmVlZGVkLiBWZXJzaW9uPDEuNC4xIHZ1bG5lcmFibGUgYnV0IGRpc3Ryb3MgdXNlIG93biB2ZXJzaW9uaW5nIHNjaGVtZS4gTWFudWFsIHZlcmlmaWNhdGlvbiBuZWVkZWQKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTAtMDgzMl0ke3R4dHJzdH0gUEFNIE1PVEQKUmVxczogcGtnPWxpYnBhbS1tb2R1bGVzLHZlcjw9MS4xLjEKVGFnczogdWJ1bnR1PTkuMTB8MTAuMDQKUmFuazogMQpleHBsb2l0LWRiOiAxNDMzOQpDb21tZW50czogU1NIIGFjY2VzcyB0byBub24gcHJpdmlsZWdlZCB1c2VyIGlzIG5lZWRlZApFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMC00MTcwXSR7dHh0cnN0fSBTeXN0ZW1UYXAKUmVxczogcGtnPXN5c3RlbXRhcCx2ZXI8PTEuMwpUYWdzOiBSSEVMPTV7c3lzdGVtdGFwOjEuMS0zLmVsNX0sZmVkb3JhPTEze3N5c3RlbXRhcDoxLjItMS5mYzEzfQpSYW5rOiAxCmF1dGhvcjogVGF2aXMgT3JtYW5keQpleHBsb2l0LWRiOiAxNTYyMApFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxMS0xNDg1XSR7dHh0cnN0fSBwa2V4ZWMKUmVxczogcGtnPXBvbGtpdCx2ZXI9MC45NgpUYWdzOiBSSEVMPTYsdWJ1bnR1PTEwLjA0fDEwLjEwClJhbms6IDEKZXhwbG9pdC1kYjogMTc5NDIKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTEtMjkyMV0ke3R4dHJzdH0ga3RzdXNzClJlcXM6IHBrZz1rdHN1c3MsdmVyPD0xLjQKVGFnczogc3Bhcmt5PTV8NgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDExLzA4LzEzLzIKc3JjLXVybDogaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2Jjb2xlcy9sb2NhbC1leHBsb2l0cy9tYXN0ZXIvQ1ZFLTIwMTEtMjkyMS9rdHN1c3MtbHBlLnNoCkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDEyLTA4MDldJHt0eHRyc3R9IGRlYXRoX3N0YXIgKHN1ZG8pClJlcXM6IHBrZz1zdWRvLHZlcj49MS44LjAsdmVyPD0xLjguMwpUYWdzOiBmZWRvcmE9MTYgClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwOi8vc2VjbGlzdHMub3JnL2Z1bGxkaXNjbG9zdXJlLzIwMTIvSmFuL2F0dC01OTAvYWR2aXNvcnlfc3Vkby50eHQKZXhwbG9pdC1kYjogMTg0MzYKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTQtMDQ3Nl0ke3R4dHJzdH0gY2hrcm9vdGtpdApSZXFzOiBwa2c9Y2hrcm9vdGtpdCx2ZXI8MC41MApUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9zZWNsaXN0cy5vcmcvb3NzLXNlYy8yMDE0L3EyLzQzMApleHBsb2l0LWRiOiAzMzg5OQpDb21tZW50czogUm9vdGluZyBkZXBlbmRzIG9uIHRoZSBjcm9udGFiICh1cCB0byBvbmUgZGF5IG9mIGRlbGF5KQpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNC01MTE5XSR7dHh0cnN0fSBfX2djb252X3RyYW5zbGl0X2ZpbmQKUmVxczogcGtnPWdsaWJjfGxpYmM2LHg4NgpUYWdzOiBkZWJpYW49NgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL2dvb2dsZXByb2plY3R6ZXJvLmJsb2dzcG90LmNvbS8yMDE0LzA4L3RoZS1wb2lzb25lZC1udWwtYnl0ZS0yMDE0LWVkaXRpb24uaHRtbApzcmMtdXJsOiBodHRwczovL2dpdGxhYi5jb20vZXhwbG9pdC1kYXRhYmFzZS9leHBsb2l0ZGItYmluLXNwbG9pdHMvLS9yYXcvbWFpbi9iaW4tc3Bsb2l0cy8zNDQyMS50YXIuZ3oKZXhwbG9pdC1kYjogMzQ0MjEKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTUtMTg2Ml0ke3R4dHJzdH0gbmV3cGlkIChhYnJ0KQpSZXFzOiBwa2c9YWJydCxjbWQ6Z3JlcCAtcWkgYWJydCAvcHJvYy9zeXMva2VybmVsL2NvcmVfcGF0dGVybgpUYWdzOiBmZWRvcmE9MjAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9vcGVud2FsbC5jb20vbGlzdHMvb3NzLXNlY3VyaXR5LzIwMTUvMDQvMTQvNApzcmMtdXJsOiBodHRwczovL2dpc3QuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3Rhdmlzby8wZjAyYzI1NWMxM2M1YzExMzQwNi9yYXcvZWFmYWM3OGRjZTUxMzI5YjAzYmVhNzE2N2YxMjcxNzE4YmVlNGRjYy9uZXdwaWQuYwpleHBsb2l0LWRiOiAzNjc0NgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS0zMzE1XSR7dHh0cnN0fSByYWNlYWJydApSZXFzOiBwa2c9YWJydCxjbWQ6Z3JlcCAtcWkgYWJydCAvcHJvYy9zeXMva2VybmVsL2NvcmVfcGF0dGVybgpUYWdzOiBmZWRvcmE9MTl7YWJydDoyLjEuNS0xLmZjMTl9LGZlZG9yYT0yMHthYnJ0OjIuMi4yLTIuZmMyMH0sZmVkb3JhPTIxe2FicnQ6Mi4zLjAtMy5mYzIxfSxSSEVMPTd7YWJydDoyLjEuMTEtMTIuZWw3fQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3NlY2xpc3RzLm9yZy9vc3Mtc2VjLzIwMTUvcTIvMTMwCnNyYy11cmw6IGh0dHBzOi8vZ2lzdC5naXRodWJ1c2VyY29udGVudC5jb20vdGF2aXNvL2ZlMzU5MDA2ODM2ZDZjZDEwOTFlL3Jhdy8zMmZlODQ4MWM0MzRmOGNhZDViY2Y4NTI5Nzg5MjMxNjI3ZTUwNzRjL3JhY2VhYnJ0LmMKZXhwbG9pdC1kYjogMzY3NDcKYXV0aG9yOiBUYXZpcyBPcm1hbmR5CkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE1LTEzMThdJHt0eHRyc3R9IG5ld3BpZCAoYXBwb3J0KQpSZXFzOiBwa2c9YXBwb3J0LHZlcj49Mi4xMyx2ZXI8PTIuMTcsY21kOmdyZXAgLXFpIGFwcG9ydCAvcHJvYy9zeXMva2VybmVsL2NvcmVfcGF0dGVybgpUYWdzOiB1YnVudHU9MTQuMDQKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly9vcGVud2FsbC5jb20vbGlzdHMvb3NzLXNlY3VyaXR5LzIwMTUvMDQvMTQvNApzcmMtdXJsOiBodHRwczovL2dpc3QuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3Rhdmlzby8wZjAyYzI1NWMxM2M1YzExMzQwNi9yYXcvZWFmYWM3OGRjZTUxMzI5YjAzYmVhNzE2N2YxMjcxNzE4YmVlNGRjYy9uZXdwaWQuYwpleHBsb2l0LWRiOiAzNjc0NgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS0xMzE4XSR7dHh0cnN0fSBuZXdwaWQgKGFwcG9ydCkgMgpSZXFzOiBwa2c9YXBwb3J0LHZlcj49Mi4xMyx2ZXI8PTIuMTcsY21kOmdyZXAgLXFpIGFwcG9ydCAvcHJvYy9zeXMva2VybmVsL2NvcmVfcGF0dGVybgpUYWdzOiB1YnVudHU9MTQuMDQuMgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL29wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNS8wNC8xNC80CmV4cGxvaXQtZGI6IDM2NzgyCkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE1LTMyMDJdJHt0eHRyc3R9IGZ1c2UgKGZ1c2VybW91bnQpClJlcXM6IHBrZz1mdXNlLHZlcjwyLjkuMwpUYWdzOiBkZWJpYW49Ny4wfDguMCx1YnVudHU9KgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL3NlY2xpc3RzLm9yZy9vc3Mtc2VjLzIwMTUvcTIvNTIwCmV4cGxvaXQtZGI6IDM3MDg5CkNvbW1lbnRzOiBOZWVkcyBjcm9uIG9yIHN5c3RlbSBhZG1pbiBpbnRlcmFjdGlvbgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS0xODE1XSR7dHh0cnN0fSBzZXRyb3VibGVzaG9vdApSZXFzOiBwa2c9c2V0cm91Ymxlc2hvb3QsdmVyPDMuMi4yMgpUYWdzOiBmZWRvcmE9MjEKUmFuazogMQpleHBsb2l0LWRiOiAzNjU2NApFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS0zMjQ2XSR7dHh0cnN0fSB1c2VyaGVscGVyClJlcXM6IHBrZz1saWJ1c2VyLHZlcjw9MC42MApUYWdzOiBSSEVMPTZ7bGlidXNlcjowLjU2LjEzLSg0fDUpLmVsNn0sUkhFTD02e2xpYnVzZXI6MC42MC01LmVsN30sZmVkb3JhPTEzfDE5fDIwfDIxfDIyClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMTUvMDcvMjMvY3ZlLTIwMTUtMzI0NS1jdmUtMjAxNS0zMjQ2L2N2ZS0yMDE1LTMyNDUtY3ZlLTIwMTUtMzI0Ni50eHQgCmV4cGxvaXQtZGI6IDM3NzA2CkNvbW1lbnRzOiBSSEVMIDUgaXMgYWxzbyB2dWxuZXJhYmxlLCBidXQgaW5zdGFsbGVkIHZlcnNpb24gb2YgZ2xpYmMgKDIuNSkgbGFja3MgZnVuY3Rpb25zIG5lZWRlZCBieSByb290aGVscGVyLmMKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTUtNTI4N10ke3R4dHJzdH0gYWJydC9zb3NyZXBvcnQtcmhlbDcKUmVxczogcGtnPWFicnQsY21kOmdyZXAgLXFpIGFicnQgL3Byb2Mvc3lzL2tlcm5lbC9jb3JlX3BhdHRlcm4KVGFnczogUkhFTD03e2FicnQ6Mi4xLjExLTEyLmVsN30KUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNS8xMi8wMS8xCnNyYy11cmw6IGh0dHBzOi8vd3d3Lm9wZW53YWxsLmNvbS9saXN0cy9vc3Mtc2VjdXJpdHkvMjAxNS8xMi8wMS8xLzEKZXhwbG9pdC1kYjogMzg4MzIKYXV0aG9yOiByZWJlbApFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS02NTY1XSR7dHh0cnN0fSBub3RfYW5fc3NobnVrZQpSZXFzOiBwa2c9b3BlbnNzaC1zZXJ2ZXIsdmVyPj02LjgsdmVyPD02LjkKVGFnczoKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDE3LzAxLzI2LzIKZXhwbG9pdC1kYjogNDExNzMKYXV0aG9yOiBGZWRlcmljbyBCZW50bwpDb21tZW50czogTmVlZHMgYWRtaW4gaW50ZXJhY3Rpb24gKHJvb3QgdXNlciBuZWVkcyB0byBsb2dpbiB2aWEgc3NoIHRvIHRyaWdnZXIgZXhwbG9pdGF0aW9uKQpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNS04NjEyXSR7dHh0cnN0fSBibHVlbWFuIHNldF9kaGNwX2hhbmRsZXIgZC1idXMgcHJpdmVzYwpSZXFzOiBwa2c9Ymx1ZW1hbix2ZXI8Mi4wLjMKVGFnczogZGViaWFuPTh7Ymx1ZW1hbjoxLjIzfQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly90d2l0dGVyLmNvbS90aGVncnVncS9zdGF0dXMvNjc3ODA5NTI3ODgyODEzNDQwCmV4cGxvaXQtZGI6IDQ2MTg2CmF1dGhvcjogU2ViYXN0aWFuIEtyYWhtZXIKQ29tbWVudHM6IERpc3Ryb3MgdXNlIG93biB2ZXJzaW9uaW5nIHNjaGVtZS4gTWFudWFsIHZlcmlmaWNhdGlvbiBuZWVkZWQuCkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE2LTEyNDBdJHt0eHRyc3R9IHRvbWNhdC1yb290cHJpdmVzYy1kZWIuc2gKUmVxczogcGtnPXRvbWNhdApUYWdzOiBkZWJpYW49OCx1YnVudHU9MTYuMDQKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vbGVnYWxoYWNrZXJzLmNvbS9hZHZpc29yaWVzL1RvbWNhdC1EZWJQa2dzLVJvb3QtUHJpdmlsZWdlLUVzY2FsYXRpb24tRXhwbG9pdC1DVkUtMjAxNi0xMjQwLmh0bWwKc3JjLXVybDogaHR0cDovL2xlZ2FsaGFja2Vycy5jb20vZXhwbG9pdHMvdG9tY2F0LXJvb3Rwcml2ZXNjLWRlYi5zaApleHBsb2l0LWRiOiA0MDQ1MAphdXRob3I6IERhd2lkIEdvbHVuc2tpCkNvbW1lbnRzOiBBZmZlY3RzIG9ubHkgRGViaWFuLWJhc2VkIGRpc3Ryb3MKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTYtMTI0N10ke3R4dHJzdH0gbmdpbnhlZC1yb290LnNoClJlcXM6IHBrZz1uZ2lueHxuZ2lueC1mdWxsLHZlcjwxLjEwLjMKVGFnczogZGViaWFuPTgsdWJ1bnR1PTE0LjA0fDE2LjA0fDE2LjEwClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2xlZ2FsaGFja2Vycy5jb20vYWR2aXNvcmllcy9OZ2lueC1FeHBsb2l0LURlYi1Sb290LVByaXZFc2MtQ1ZFLTIwMTYtMTI0Ny5odG1sCnNyYy11cmw6IGh0dHBzOi8vbGVnYWxoYWNrZXJzLmNvbS9leHBsb2l0cy9DVkUtMjAxNi0xMjQ3L25naW54ZWQtcm9vdC5zaApleHBsb2l0LWRiOiA0MDc2OAphdXRob3I6IERhd2lkIEdvbHVuc2tpCkNvbW1lbnRzOiBSb290aW5nIGRlcGVuZHMgb24gY3Jvbi5kYWlseSAodXAgdG8gMjRoIG9mIGRlbGF5KS4gQWZmZWN0ZWQ6IGRlYjg6IDwxLjYuMjsgMTQuMDQ6IDwxLjQuNjsgMTYuMDQ6IDEuMTAuMDsgZ2VudG9vOiA8MS4xMC4yLXIzCkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDE2LTE1MzFdJHt0eHRyc3R9IHBlcmxfc3RhcnR1cCAoZXhpbSkKUmVxczogcGtnPWV4aW0sdmVyPDQuODYuMgpUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly93d3cuZXhpbS5vcmcvc3RhdGljL2RvYy9DVkUtMjAxNi0xNTMxLnR4dApleHBsb2l0LWRiOiAzOTU0OQpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi0xNTMxXSR7dHh0cnN0fSBwZXJsX3N0YXJ0dXAgKGV4aW0pIDIKUmVxczogcGtnPWV4aW0sdmVyPDQuODYuMgpUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHA6Ly93d3cuZXhpbS5vcmcvc3RhdGljL2RvYy9DVkUtMjAxNi0xNTMxLnR4dApleHBsb2l0LWRiOiAzOTUzNQpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi00OTg5XSR7dHh0cnN0fSBzZXRyb3VibGVzaG9vdCAyClJlcXM6IHBrZz1zZXRyb3VibGVzaG9vdApUYWdzOiBSSEVMPTZ8NwpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9jLXNraWxscy5ibG9nc3BvdC5jb20vMjAxNi8wNi9sZXRzLWZlZWQtYXR0YWNrZXItaW5wdXQtdG8tc2gtYy10by1zZWUuaHRtbApzcmMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vc3RlYWx0aC90cm91Ymxlc2hvb3Rlci9yYXcvbWFzdGVyL3N0cmFpZ2h0LXNob290ZXIuYwpleHBsb2l0LWRiOgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi01NDI1XSR7dHh0cnN0fSB0b21jYXQtUkgtcm9vdC5zaApSZXFzOiBwa2c9dG9tY2F0ClRhZ3M6IFJIRUw9NwpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cDovL2xlZ2FsaGFja2Vycy5jb20vYWR2aXNvcmllcy9Ub21jYXQtUmVkSGF0LVBrZ3MtUm9vdC1Qcml2RXNjLUV4cGxvaXQtQ1ZFLTIwMTYtNTQyNS5odG1sCnNyYy11cmw6IGh0dHA6Ly9sZWdhbGhhY2tlcnMuY29tL2V4cGxvaXRzL3RvbWNhdC1SSC1yb290LnNoCmV4cGxvaXQtZGI6IDQwNDg4CmF1dGhvcjogRGF3aWQgR29sdW5za2kKQ29tbWVudHM6IEFmZmVjdHMgb25seSBSZWRIYXQtYmFzZWQgZGlzdHJvcwpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNi02NjYzLENWRS0yMDE2LTY2NjR8Q1ZFLTIwMTYtNjY2Ml0ke3R4dHJzdH0gbXlzcWwtZXhwbG9pdC1jaGFpbgpSZXFzOiBwa2c9bXlzcWwtc2VydmVyfG1hcmlhZGItc2VydmVyLHZlcjw1LjUuNTIKVGFnczogdWJ1bnR1PTE2LjA0LjEKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vbGVnYWxoYWNrZXJzLmNvbS9hZHZpc29yaWVzL015U1FMLU1hcmlhLVBlcmNvbmEtUHJpdkVzY1JhY2UtQ1ZFLTIwMTYtNjY2My01NjE2LUV4cGxvaXQuaHRtbApzcmMtdXJsOiBodHRwOi8vbGVnYWxoYWNrZXJzLmNvbS9leHBsb2l0cy9DVkUtMjAxNi02NjYzL215c3FsLXByaXZlc2MtcmFjZS5jCmV4cGxvaXQtZGI6IDQwNjc4CmF1dGhvcjogRGF3aWQgR29sdW5za2kKQ29tbWVudHM6IEFsc28gTWFyaWFEQiB2ZXI8MTAuMS4xOCBhbmQgdmVyPDEwLjAuMjggYWZmZWN0ZWQKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTYtOTU2Nl0ke3R4dHJzdH0gbmFnaW9zLXJvb3QtcHJpdmVzYwpSZXFzOiBwa2c9bmFnaW9zLHZlcjw0LjIuNApUYWdzOgpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9sZWdhbGhhY2tlcnMuY29tL2Fkdmlzb3JpZXMvTmFnaW9zLUV4cGxvaXQtUm9vdC1Qcml2RXNjLUNWRS0yMDE2LTk1NjYuaHRtbApzcmMtdXJsOiBodHRwczovL2xlZ2FsaGFja2Vycy5jb20vZXhwbG9pdHMvQ1ZFLTIwMTYtOTU2Ni9uYWdpb3Mtcm9vdC1wcml2ZXNjLnNoCmV4cGxvaXQtZGI6IDQwOTIxCmF1dGhvcjogRGF3aWQgR29sdW5za2kKQ29tbWVudHM6IEFsbG93cyBwcml2IGVzY2FsYXRpb24gZnJvbSBuYWdpb3MgdXNlciBvciBuYWdpb3MgZ3JvdXAKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMDM1OF0ke3R4dHJzdH0gbnRmcy0zZy1tb2Rwcm9iZQpSZXFzOiBwa2c9bnRmcy0zZyx2ZXI8MjAxNy40ClRhZ3M6IHVidW50dT0xNi4wNHtudGZzLTNnOjIwMTUuMy4xNEFSLjEtMWJ1aWxkMX0sZGViaWFuPTcuMHtudGZzLTNnOjIwMTIuMS4xNUFSLjUtMi4xK2RlYjd1Mn0sZGViaWFuPTguMHtudGZzLTNnOjIwMTQuMi4xNUFSLjItMStkZWI4dTJ9ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2J1Z3MuY2hyb21pdW0ub3JnL3AvcHJvamVjdC16ZXJvL2lzc3Vlcy9kZXRhaWw/aWQ9MTA3MgpzcmMtdXJsOiBodHRwczovL2dpdGxhYi5jb20vZXhwbG9pdC1kYXRhYmFzZS9leHBsb2l0ZGItYmluLXNwbG9pdHMvLS9yYXcvbWFpbi9iaW4tc3Bsb2l0cy80MTM1Ni56aXAKZXhwbG9pdC1kYjogNDEzNTYKYXV0aG9yOiBKYW5uIEhvcm4KQ29tbWVudHM6IERpc3Ryb3MgdXNlIG93biB2ZXJzaW9uaW5nIHNjaGVtZS4gTWFudWFsIHZlcmlmaWNhdGlvbiBuZWVkZWQuIExpbnV4IGhlYWRlcnMgbXVzdCBiZSBpbnN0YWxsZWQuIFN5c3RlbSBtdXN0IGhhdmUgYXQgbGVhc3QgdHdvIENQVSBjb3Jlcy4KRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctNTg5OV0ke3R4dHJzdH0gcy1uYWlsLXByaXZnZXQKUmVxczogcGtnPXMtbmFpbCx2ZXI8MTQuOC4xNgpUYWdzOiB1YnVudHU9MTYuMDQsbWFuamFybz0xNi4xMApSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDE3LzAxLzI3LzcKc3JjLXVybDogaHR0cHM6Ly93d3cub3BlbndhbGwuY29tL2xpc3RzL29zcy1zZWN1cml0eS8yMDE3LzAxLzI3LzcvMQpleHQtdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vYmNvbGVzL2xvY2FsLWV4cGxvaXRzL21hc3Rlci9DVkUtMjAxNy01ODk5L2V4cGxvaXQuc2gKYXV0aG9yOiB3YXBpZmxhcGkgKG9yZ2luYWwgZXhwbG9pdCBhdXRob3IpOyBCcmVuZGFuIENvbGVzIChhdXRob3Igb2YgZXhwbG9pdCB1cGRhdGUgYXQgJ2V4dC11cmwnKQpDb21tZW50czogRGlzdHJvcyB1c2Ugb3duIHZlcnNpb25pbmcgc2NoZW1lLiBNYW51YWwgdmVyaWZpY2F0aW9uIG5lZWRlZC4KRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMTAwMDM2N10ke3R4dHJzdH0gU3Vkb2VyLXRvLXJvb3QKUmVxczogcGtnPXN1ZG8sdmVyPD0xLjguMjAsY21kOlsgLWYgL3Vzci9zYmluL2dldGVuZm9yY2UgXQpUYWdzOiBSSEVMPTd7c3VkbzoxLjguNnA3fQpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cuc3Vkby53cy9hbGVydHMvbGludXhfdHR5Lmh0bWwKc3JjLXVybDogaHR0cHM6Ly93d3cucXVhbHlzLmNvbS8yMDE3LzA1LzMwL2N2ZS0yMDE3LTEwMDAzNjcvbGludXhfc3Vkb19jdmUtMjAxNy0xMDAwMzY3LmMKZXhwbG9pdC1kYjogNDIxODMKYXV0aG9yOiBRdWFseXMKQ29tbWVudHM6IE5lZWRzIHRvIGJlIHN1ZG9lci4gV29ya3Mgb25seSBvbiBTRUxpbnV4IGVuYWJsZWQgc3lzdGVtcwpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNy0xMDAwMzY3XSR7dHh0cnN0fSBzdWRvcHduClJlcXM6IHBrZz1zdWRvLHZlcjw9MS44LjIwLGNtZDpbIC1mIC91c3Ivc2Jpbi9nZXRlbmZvcmNlIF0KVGFnczoKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3LnN1ZG8ud3MvYWxlcnRzL2xpbnV4X3R0eS5odG1sCnNyYy11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9jMGQzejNyMC9zdWRvLUNWRS0yMDE3LTEwMDAzNjcvbWFzdGVyL3N1ZG9wd24uYwpleHBsb2l0LWRiOgphdXRob3I6IGMwZDN6M3IwCkNvbW1lbnRzOiBOZWVkcyB0byBiZSBzdWRvZXIuIFdvcmtzIG9ubHkgb24gU0VMaW51eCBlbmFibGVkIHN5c3RlbXMKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMTAwMDM2NixDVkUtMjAxNy0xMDAwMzcwXSR7dHh0cnN0fSBsaW51eF9sZHNvX2h3Y2FwClJlcXM6IHBrZz1nbGliY3xsaWJjNix2ZXI8PTIuMjUseDg2ClRhZ3M6ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMTcvMDYvMTkvc3RhY2stY2xhc2gvc3RhY2stY2xhc2gudHh0CnNyYy11cmw6IGh0dHBzOi8vd3d3LnF1YWx5cy5jb20vMjAxNy8wNi8xOS9zdGFjay1jbGFzaC9saW51eF9sZHNvX2h3Y2FwLmMKZXhwbG9pdC1kYjogNDIyNzQKYXV0aG9yOiBRdWFseXMKQ29tbWVudHM6IFVzZXMgIlN0YWNrIENsYXNoIiB0ZWNobmlxdWUsIHdvcmtzIGFnYWluc3QgbW9zdCBTVUlELXJvb3QgYmluYXJpZXMKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMTAwMDM2NixDVkUtMjAxNy0xMDAwMzcxXSR7dHh0cnN0fSBsaW51eF9sZHNvX2R5bmFtaWMKUmVxczogcGtnPWdsaWJjfGxpYmM2LHZlcjw9Mi4yNSx4ODYKVGFnczogZGViaWFuPTl8MTAsdWJ1bnR1PTE0LjA0LjV8MTYuMDQuMnwxNy4wNCxmZWRvcmE9MjN8MjR8MjUKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3LnF1YWx5cy5jb20vMjAxNy8wNi8xOS9zdGFjay1jbGFzaC9zdGFjay1jbGFzaC50eHQKc3JjLXVybDogaHR0cHM6Ly93d3cucXVhbHlzLmNvbS8yMDE3LzA2LzE5L3N0YWNrLWNsYXNoL2xpbnV4X2xkc29fZHluYW1pYy5jCmV4cGxvaXQtZGI6IDQyMjc2CmF1dGhvcjogUXVhbHlzCkNvbW1lbnRzOiBVc2VzICJTdGFjayBDbGFzaCIgdGVjaG5pcXVlLCB3b3JrcyBhZ2FpbnN0IG1vc3QgU1VJRC1yb290IFBJRXMKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctMTAwMDM2NixDVkUtMjAxNy0xMDAwMzc5XSR7dHh0cnN0fSBsaW51eF9sZHNvX2h3Y2FwXzY0ClJlcXM6IHBrZz1nbGliY3xsaWJjNix2ZXI8PTIuMjUseDg2XzY0ClRhZ3M6IGRlYmlhbj03Ljd8OC41fDkuMCx1YnVudHU9MTQuMDQuMnwxNi4wNC4yfDE3LjA0LGZlZG9yYT0yMnwyNSxjZW50b3M9Ny4zLjE2MTEKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3LnF1YWx5cy5jb20vMjAxNy8wNi8xOS9zdGFjay1jbGFzaC9zdGFjay1jbGFzaC50eHQKc3JjLXVybDogaHR0cHM6Ly93d3cucXVhbHlzLmNvbS8yMDE3LzA2LzE5L3N0YWNrLWNsYXNoL2xpbnV4X2xkc29faHdjYXBfNjQuYwpleHBsb2l0LWRiOiA0MjI3NQphdXRob3I6IFF1YWx5cwpDb21tZW50czogVXNlcyAiU3RhY2sgQ2xhc2giIHRlY2huaXF1ZSwgd29ya3MgYWdhaW5zdCBtb3N0IFNVSUQtcm9vdCBiaW5hcmllcwpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxNy0xMDAwMzcwLENWRS0yMDE3LTEwMDAzNzFdJHt0eHRyc3R9IGxpbnV4X29mZnNldDJsaWIKUmVxczogcGtnPWdsaWJjfGxpYmM2LHZlcjw9Mi4yNSx4ODYKVGFnczoKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3LnF1YWx5cy5jb20vMjAxNy8wNi8xOS9zdGFjay1jbGFzaC9zdGFjay1jbGFzaC50eHQKc3JjLXVybDogaHR0cHM6Ly93d3cucXVhbHlzLmNvbS8yMDE3LzA2LzE5L3N0YWNrLWNsYXNoL2xpbnV4X29mZnNldDJsaWIuYwpleHBsb2l0LWRiOiA0MjI3MwphdXRob3I6IFF1YWx5cwpDb21tZW50czogVXNlcyAiU3RhY2sgQ2xhc2giIHRlY2huaXF1ZQpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOC0xMDAwMDAxXSR7dHh0cnN0fSBSYXRpb25hbExvdmUKUmVxczogcGtnPWdsaWJjfGxpYmM2LHZlcjwyLjI3LENPTkZJR19VU0VSX05TPXksc3lzY3RsOmtlcm5lbC51bnByaXZpbGVnZWRfdXNlcm5zX2Nsb25lPT0xLHg4Nl82NApUYWdzOiBkZWJpYW49OXtsaWJjNjoyLjI0LTExK2RlYjl1MX0sdWJ1bnR1PTE2LjA0LjN7bGliYzY6Mi4yMy0wdWJ1bnR1OX0KUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3LmhhbGZkb2cubmV0L1NlY3VyaXR5LzIwMTcvTGliY1JlYWxwYXRoQnVmZmVyVW5kZXJmbG93LwpzcmMtdXJsOiBodHRwczovL3d3dy5oYWxmZG9nLm5ldC9TZWN1cml0eS8yMDE3L0xpYmNSZWFscGF0aEJ1ZmZlclVuZGVyZmxvdy9SYXRpb25hbExvdmUuYwpDb21tZW50czoga2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9MSByZXF1aXJlZApiaW4tdXJsOiBodHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vcmFwaWQ3L21ldGFzcGxvaXQtZnJhbWV3b3JrL21hc3Rlci9kYXRhL2V4cGxvaXRzL2N2ZS0yMDE4LTEwMDAwMDEvUmF0aW9uYWxMb3ZlCmV4cGxvaXQtZGI6IDQzNzc1CmF1dGhvcjogaGFsZmRvZwpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOC0xMDkwMF0ke3R4dHJzdH0gdnBuY19wcml2ZXNjLnB5ClJlcXM6IHBrZz1uZXR3b3JrbWFuYWdlci12cG5jfG5ldHdvcmstbWFuYWdlci12cG5jLHZlcjwxLjIuNgpUYWdzOiB1YnVudHU9MTYuMDR7bmV0d29yay1tYW5hZ2VyLXZwbmM6MS4xLjkzLTF9LGRlYmlhbj05LjB7bmV0d29yay1tYW5hZ2VyLXZwbmM6MS4yLjQtNH0sbWFuamFybz0xNwpSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9wdWxzZXNlY3VyaXR5LmNvLm56L2Fkdmlzb3JpZXMvTk0tVlBOQy1Qcml2ZXNjCnNyYy11cmw6IGh0dHBzOi8vYnVnemlsbGEubm92ZWxsLmNvbS9hdHRhY2htZW50LmNnaT9pZD03NzkxMTAKZXhwbG9pdC1kYjogNDUzMTMKYXV0aG9yOiBEZW5pcyBBbmR6YWtvdmljCkNvbW1lbnRzOiBEaXN0cm9zIHVzZSBvd24gdmVyc2lvbmluZyBzY2hlbWUuIE1hbnVhbCB2ZXJpZmljYXRpb24gbmVlZGVkLgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOC0xNDY2NV0ke3R4dHJzdH0gcmFwdG9yX3hvcmd5ClJlcXM6IHBrZz14b3JnLXgxMS1zZXJ2ZXItWG9yZyxjbWQ6WyAtdSAvdXNyL2Jpbi9Yb3JnIF0KVGFnczogY2VudG9zPTcuNApSYW5rOiAxCmFuYWx5c2lzLXVybDogaHR0cHM6Ly93d3cuc2VjdXJlcGF0dGVybnMuY29tLzIwMTgvMTAvY3ZlLTIwMTgtMTQ2NjUteG9yZy14LXNlcnZlci5odG1sCmV4cGxvaXQtZGI6IDQ1OTIyCmF1dGhvcjogcmFwdG9yCkNvbW1lbnRzOiBYLk9yZyBTZXJ2ZXIgYmVmb3JlIDEuMjAuMyBpcyB2dWxuZXJhYmxlLiBEaXN0cm9zIHVzZSBvd24gdmVyc2lvbmluZyBzY2hlbWUuIE1hbnVhbCB2ZXJpZmljYXRpb24gbmVlZGVkLgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOS03MzA0XSR7dHh0cnN0fSBkaXJ0eV9zb2NrClJlcXM6IHBrZz1zbmFwZCx2ZXI8Mi4zNyxjbWQ6WyAtUyAvcnVuL3NuYXBkLnNvY2tldCBdClRhZ3M6IHVidW50dT0xOC4xMCxtaW50PTE5ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2luaXRibG9nLmNvbS8yMDE5L2RpcnR5LXNvY2svCmV4cGxvaXQtZGI6IDQ2MzYxCmV4cGxvaXQtZGI6IDQ2MzYyCnNyYy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9pbml0c3RyaW5nL2RpcnR5X3NvY2svYXJjaGl2ZS9tYXN0ZXIuemlwCmF1dGhvcjogSW5pdFN0cmluZwpDb21tZW50czogRGlzdHJvcyB1c2Ugb3duIHZlcnNpb25pbmcgc2NoZW1lLiBNYW51YWwgdmVyaWZpY2F0aW9uIG5lZWRlZC4KRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTktMTAxNDldJHt0eHRyc3R9IHJhcHRvcl9leGltX3dpegpSZXFzOiBwa2c9ZXhpbXxleGltNCx2ZXI+PTQuODcsdmVyPD00LjkxClRhZ3M6ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMTkvMDYvMDUvY3ZlLTIwMTktMTAxNDkvcmV0dXJuLXdpemFyZC1yY2UtZXhpbS50eHQKZXhwbG9pdC1kYjogNDY5OTYKYXV0aG9yOiByYXB0b3IKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTktMTIxODFdJHt0eHRyc3R9IFNlcnYtVSBGVFAgU2VydmVyClJlcXM6IGNtZDpbIC11IC91c3IvbG9jYWwvU2Vydi1VL1NlcnYtVSBdClRhZ3M6IGRlYmlhbj05ClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL2Jsb2cudmFzdGFydC5kZXYvMjAxOS8wNi9jdmUtMjAxOS0xMjE4MS1zZXJ2LXUtZXhwbG9pdC13cml0ZXVwLmh0bWwKZXhwbG9pdC1kYjogNDcwMDkKc3JjLXVybDogaHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2d1eXdoYXRhZ3V5L0NWRS0yMDE5LTEyMTgxL21hc3Rlci9zZXJ2dS1wZS1jdmUtMjAxOS0xMjE4MS5jCmV4dC11cmw6IGh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS9iY29sZXMvbG9jYWwtZXhwbG9pdHMvbWFzdGVyL0NWRS0yMDE5LTEyMTgxL1NVcm9vdAphdXRob3I6IEd1eSBMZXZpbiAob3JnaW5hbCBleHBsb2l0IGF1dGhvcik7IEJyZW5kYW4gQ29sZXMgKGF1dGhvciBvZiBleHBsb2l0IHVwZGF0ZSBhdCAnZXh0LXVybCcpCkNvbW1lbnRzOiBNb2RpZmllZCB2ZXJzaW9uIGF0ICdleHQtdXJsJyB1c2VzIGJhc2ggZXhlYyB0ZWNobmlxdWUsIHJhdGhlciB0aGFuIGNvbXBpbGluZyB3aXRoIGdjYy4KRU9GCikKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAxOS0xODg2Ml0ke3R4dHJzdH0gR05VIE1haWx1dGlscyAyLjAgPD0gMy43IG1haWRhZyB1cmwgbG9jYWwgcm9vdCAoQ1ZFLTIwMTktMTg4NjIpClJlcXM6IGNtZDpbIC11IC91c3IvbG9jYWwvc2Jpbi9tYWlkYWcgXQpUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3Lm1pa2UtZ3VhbHRpZXJpLmNvbS9wb3N0cy9maW5kaW5nLWEtZGVjYWRlLW9sZC1mbGF3LWluLWdudS1tYWlsdXRpbHMKZXh0LXVybDogaHR0cHM6Ly9naXRodWIuY29tL2Jjb2xlcy9sb2NhbC1leHBsb2l0cy9yYXcvbWFzdGVyL0NWRS0yMDE5LTE4ODYyL2V4cGxvaXQuY3Jvbi5zaApzcmMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vYmNvbGVzL2xvY2FsLWV4cGxvaXRzL3Jhdy9tYXN0ZXIvQ1ZFLTIwMTktMTg4NjIvZXhwbG9pdC5sZHByZWxvYWQuc2gKYXV0aG9yOiBiY29sZXMKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTktMTg2MzRdJHt0eHRyc3R9IHN1ZG8gcHdmZWVkYmFjawpSZXFzOiBwa2c9c3Vkbyx2ZXI8MS44LjMxClRhZ3M6IG1pbnQ9MTkKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vZHlsYW5rYXR6LmNvbS9BbmFseXNpcy1vZi1DVkUtMjAxOS0xODYzNC8Kc3JjLXVybDogaHR0cHM6Ly9naXRodWIuY29tL3NhbGVlbXJhc2hpZC9zdWRvLWN2ZS0yMDE5LTE4NjM0L3Jhdy9tYXN0ZXIvZXhwbG9pdC5jCmF1dGhvcjogc2FsZWVtcmFzaGlkCkNvbW1lbnRzOiBzdWRvIGNvbmZpZ3VyYXRpb24gcmVxdWlyZXMgcHdmZWVkYmFjayB0byBiZSBlbmFibGVkLgpFT0YKKQoKRVhQTE9JVFNfVVNFUlNQQUNFWygobisrKSldPSQoY2F0IDw8RU9GCk5hbWU6ICR7dHh0Z3JufVtDVkUtMjAyMC05NDcwXSR7dHh0cnN0fSBXaW5nIEZUUCBTZXJ2ZXIgPD0gNi4yLjUgTFBFClJlcXM6IGNtZDpbIC14IC9ldGMvaW5pdC5kL3dmdHBzZXJ2ZXIgXQpUYWdzOiB1YnVudHU9MTgKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vd3d3Lmhvb3BlcmxhYnMueHl6L2Rpc2Nsb3N1cmVzL2N2ZS0yMDIwLTk0NzAucGhwCnNyYy11cmw6IGh0dHBzOi8vd3d3Lmhvb3BlcmxhYnMueHl6L2Rpc2Nsb3N1cmVzL2N2ZS0yMDIwLTk0NzAuc2gKZXhwbG9pdC1kYjogNDgxNTQKYXV0aG9yOiBDYXJ5IENvb3BlcgpDb21tZW50czogUmVxdWlyZXMgYW4gYWRtaW5pc3RyYXRvciB0byBsb2dpbiB2aWEgdGhlIHdlYiBpbnRlcmZhY2UuCkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDIxLTMxNTZdJHt0eHRyc3R9IHN1ZG8gQmFyb24gU2FtZWRpdApSZXFzOiBwa2c9c3Vkbyx2ZXI8MS45LjVwMgpUYWdzOiBtaW50PTE5LHVidW50dT0xOHwyMCwgZGViaWFuPTEwClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMjEvMDEvMjYvY3ZlLTIwMjEtMzE1Ni9iYXJvbi1zYW1lZGl0LWhlYXAtYmFzZWQtb3ZlcmZsb3ctc3Vkby50eHQKc3JjLXVybDogaHR0cHM6Ly9jb2RlbG9hZC5naXRodWIuY29tL2JsYXN0eS9DVkUtMjAyMS0zMTU2L3ppcC9tYWluCmF1dGhvcjogYmxhc3R5CkVPRgopCgpFWFBMT0lUU19VU0VSU1BBQ0VbKChuKyspKV09JChjYXQgPDxFT0YKTmFtZTogJHt0eHRncm59W0NWRS0yMDIxLTMxNTZdJHt0eHRyc3R9IHN1ZG8gQmFyb24gU2FtZWRpdCAyClJlcXM6IHBrZz1zdWRvLHZlcjwxLjkuNXAyClRhZ3M6IGNlbnRvcz02fDd8OCx1YnVudHU9MTR8MTZ8MTd8MTh8MTl8MjAsIGRlYmlhbj05fDEwClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMjEvMDEvMjYvY3ZlLTIwMjEtMzE1Ni9iYXJvbi1zYW1lZGl0LWhlYXAtYmFzZWQtb3ZlcmZsb3ctc3Vkby50eHQKc3JjLXVybDogaHR0cHM6Ly9jb2RlbG9hZC5naXRodWIuY29tL3dvcmF3aXQvQ1ZFLTIwMjEtMzE1Ni96aXAvbWFpbgphdXRob3I6IHdvcmF3aXQKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMTctNTYxOF0ke3R4dHJzdH0gc2V0dWlkIHNjcmVlbiB2NC41LjAgTFBFClJlcXM6IHBrZz1zY3JlZW4sdmVyPT00LjUuMApUYWdzOiAKUmFuazogMQphbmFseXNpcy11cmw6IGh0dHBzOi8vc2VjbGlzdHMub3JnL29zcy1zZWMvMjAxNy9xMS8xODQKZXhwbG9pdC1kYjogaHR0cHM6Ly93d3cuZXhwbG9pdC1kYi5jb20vZXhwbG9pdHMvNDExNTQKRU9GCikKCkVYUExPSVRTX1VTRVJTUEFDRVsoKG4rKykpXT0kKGNhdCA8PEVPRgpOYW1lOiAke3R4dGdybn1bQ1ZFLTIwMjEtNDAzNF0ke3R4dHJzdH0gUHduS2l0ClJlcXM6IHBrZz1wb2xraXR8cG9saWN5a2l0LTEsdmVyPD0wLjEwNS0zMQpUYWdzOiB1YnVudHU9MTB8MTF8MTJ8MTN8MTR8MTV8MTZ8MTd8MTh8MTl8MjB8MjEsZGViaWFuPTd8OHw5fDEwfDExLGZlZG9yYSxtYW5qYXJvClJhbms6IDEKYW5hbHlzaXMtdXJsOiBodHRwczovL3d3dy5xdWFseXMuY29tLzIwMjIvMDEvMjUvY3ZlLTIwMjEtNDAzNC9wd25raXQudHh0CnNyYy11cmw6IGh0dHBzOi8vY29kZWxvYWQuZ2l0aHViLmNvbS9iZXJkYXYvQ1ZFLTIwMjEtNDAzNC96aXAvbWFpbgphdXRob3I6IGJlcmRhdgpFT0YKKQoKIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMKIyMgc2VjdXJpdHkgcmVsYXRlZCBIVy9rZXJuZWwgZmVhdHVyZXMKIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMKbj0wCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpzZWN0aW9uOiBNYWlubGluZSBrZXJuZWwgcHJvdGVjdGlvbiBtZWNoYW5pc21zOgpFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogS2VybmVsIFBhZ2UgVGFibGUgSXNvbGF0aW9uIChQVEkpIHN1cHBvcnQKYXZhaWxhYmxlOiB2ZXI+PTQuMTUKZW5hYmxlZDogY21kOmdyZXAgLUVxaSAnXHNwdGknIC9wcm9jL2NwdWluZm8KYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9wdGkubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IEdDQyBzdGFjayBwcm90ZWN0b3Igc3VwcG9ydAphdmFpbGFibGU6IENPTkZJR19IQVZFX1NUQUNLUFJPVEVDVE9SPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9zdGFja3Byb3RlY3Rvci1yZWd1bGFyLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBHQ0Mgc3RhY2sgcHJvdGVjdG9yIFNUUk9ORyBzdXBwb3J0CmF2YWlsYWJsZTogQ09ORklHX1NUQUNLUFJPVEVDVE9SX1NUUk9ORz15LHZlcj49My4xNAphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL3N0YWNrcHJvdGVjdG9yLXN0cm9uZy5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogTG93IGFkZHJlc3Mgc3BhY2UgdG8gcHJvdGVjdCBmcm9tIHVzZXIgYWxsb2NhdGlvbgphdmFpbGFibGU6IENPTkZJR19ERUZBVUxUX01NQVBfTUlOX0FERFI9WzAtOV0rCmVuYWJsZWQ6IHN5c2N0bDp2bS5tbWFwX21pbl9hZGRyIT0wCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvbW1hcF9taW5fYWRkci5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogUHJldmVudCB1c2VycyBmcm9tIHVzaW5nIHB0cmFjZSB0byBleGFtaW5lIHRoZSBtZW1vcnkgYW5kIHN0YXRlIG9mIHRoZWlyIHByb2Nlc3NlcwphdmFpbGFibGU6IENPTkZJR19TRUNVUklUWV9ZQU1BPXkKZW5hYmxlZDogc3lzY3RsOmtlcm5lbC55YW1hLnB0cmFjZV9zY29wZSE9MAphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL3lhbWFfcHRyYWNlX3Njb3BlLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBSZXN0cmljdCB1bnByaXZpbGVnZWQgYWNjZXNzIHRvIGtlcm5lbCBzeXNsb2cKYXZhaWxhYmxlOiBDT05GSUdfU0VDVVJJVFlfRE1FU0dfUkVTVFJJQ1Q9eSx2ZXI+PTIuNi4zNwplbmFibGVkOiBzeXNjdGw6a2VybmVsLmRtZXNnX3Jlc3RyaWN0IT0wCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvZG1lc2dfcmVzdHJpY3QubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFJhbmRvbWl6ZSB0aGUgYWRkcmVzcyBvZiB0aGUga2VybmVsIGltYWdlIChLQVNMUikKYXZhaWxhYmxlOiBDT05GSUdfUkFORE9NSVpFX0JBU0U9eQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL2thc2xyLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBIYXJkZW5lZCB1c2VyIGNvcHkgc3VwcG9ydAphdmFpbGFibGU6IENPTkZJR19IQVJERU5FRF9VU0VSQ09QWT15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvaGFyZGVuZWRfdXNlcmNvcHkubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IE1ha2Uga2VybmVsIHRleHQgYW5kIHJvZGF0YSByZWFkLW9ubHkKYXZhaWxhYmxlOiBDT05GSUdfU1RSSUNUX0tFUk5FTF9SV1g9eQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL3N0cmljdF9rZXJuZWxfcnd4Lm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBTZXQgbG9hZGFibGUga2VybmVsIG1vZHVsZSBkYXRhIGFzIE5YIGFuZCB0ZXh0IGFzIFJPCmF2YWlsYWJsZTogQ09ORklHX1NUUklDVF9NT0RVTEVfUldYPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9zdHJpY3RfbW9kdWxlX3J3eC5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogQlVHKCkgY29uZGl0aW9ucyByZXBvcnRpbmcKYXZhaWxhYmxlOiBDT05GSUdfQlVHPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9idWcubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IEFkZGl0aW9uYWwgJ2NyZWQnIHN0cnVjdCBjaGVja3MKYXZhaWxhYmxlOiBDT05GSUdfREVCVUdfQ1JFREVOVElBTFM9eQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL2RlYnVnX2NyZWRlbnRpYWxzLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBTYW5pdHkgY2hlY2tzIGZvciBub3RpZmllciBjYWxsIGNoYWlucwphdmFpbGFibGU6IENPTkZJR19ERUJVR19OT1RJRklFUlM9eQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL2RlYnVnX25vdGlmaWVycy5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogRXh0ZW5kZWQgY2hlY2tzIGZvciBsaW5rZWQtbGlzdHMgd2Fsa2luZwphdmFpbGFibGU6IENPTkZJR19ERUJVR19MSVNUPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9kZWJ1Z19saXN0Lm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBDaGVja3Mgb24gc2NhdHRlci1nYXRoZXIgdGFibGVzCmF2YWlsYWJsZTogQ09ORklHX0RFQlVHX1NHPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9kZWJ1Z19zZy5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogQ2hlY2tzIGZvciBkYXRhIHN0cnVjdHVyZSBjb3JydXB0aW9ucwphdmFpbGFibGU6IENPTkZJR19CVUdfT05fREFUQV9DT1JSVVBUSU9OPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9idWdfb25fZGF0YV9jb3JydXB0aW9uLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBDaGVja3MgZm9yIGEgc3RhY2sgb3ZlcnJ1biBvbiBjYWxscyB0byAnc2NoZWR1bGUnCmF2YWlsYWJsZTogQ09ORklHX1NDSEVEX1NUQUNLX0VORF9DSEVDSz15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvc2NoZWRfc3RhY2tfZW5kX2NoZWNrLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBGcmVlbGlzdCBvcmRlciByYW5kb21pemF0aW9uIG9uIG5ldyBwYWdlcyBjcmVhdGlvbgphdmFpbGFibGU6IENPTkZJR19TTEFCX0ZSRUVMSVNUX1JBTkRPTT15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvc2xhYl9mcmVlbGlzdF9yYW5kb20ubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IEZyZWVsaXN0IG1ldGFkYXRhIGhhcmRlbmluZwphdmFpbGFibGU6IENPTkZJR19TTEFCX0ZSRUVMSVNUX0hBUkRFTkVEPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9zbGFiX2ZyZWVsaXN0X2hhcmRlbmVkLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBBbGxvY2F0b3IgdmFsaWRhdGlvbiBjaGVja2luZwphdmFpbGFibGU6IENPTkZJR19TTFVCX0RFQlVHX09OPXksY21kOiEgZ3JlcCAnc2x1Yl9kZWJ1Zz0tJyAvcHJvYy9jbWRsaW5lCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvc2x1Yl9kZWJ1Zy5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogVmlydHVhbGx5LW1hcHBlZCBrZXJuZWwgc3RhY2tzIHdpdGggZ3VhcmQgcGFnZXMKYXZhaWxhYmxlOiBDT05GSUdfVk1BUF9TVEFDSz15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvdm1hcF9zdGFjay5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogUGFnZXMgcG9pc29uaW5nIGFmdGVyIGZyZWVfcGFnZXMoKSBjYWxsCmF2YWlsYWJsZTogQ09ORklHX1BBR0VfUE9JU09OSU5HPXkKZW5hYmxlZDogY21kOiBncmVwICdwYWdlX3BvaXNvbj0xJyAvcHJvYy9jbWRsaW5lCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvcGFnZV9wb2lzb25pbmcubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFVzaW5nICdyZWZjb3VudF90JyBpbnN0ZWFkIG9mICdhdG9taWNfdCcKYXZhaWxhYmxlOiBDT05GSUdfUkVGQ09VTlRfRlVMTD15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvcmVmY291bnRfZnVsbC5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogSGFyZGVuaW5nIGNvbW1vbiBzdHIvbWVtIGZ1bmN0aW9ucyBhZ2FpbnN0IGJ1ZmZlciBvdmVyZmxvd3MKYXZhaWxhYmxlOiBDT05GSUdfRk9SVElGWV9TT1VSQ0U9eQphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL2ZvcnRpZnlfc291cmNlLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBSZXN0cmljdCAvZGV2L21lbSBhY2Nlc3MKYXZhaWxhYmxlOiBDT05GSUdfU1RSSUNUX0RFVk1FTT15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvc3RyaWN0X2Rldm1lbS5tZApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogUmVzdHJpY3QgSS9PIGFjY2VzcyB0byAvZGV2L21lbQphdmFpbGFibGU6IENPTkZJR19JT19TVFJJQ1RfREVWTUVNPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9pb19zdHJpY3RfZGV2bWVtLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpzZWN0aW9uOiBIYXJkd2FyZS1iYXNlZCBwcm90ZWN0aW9uIGZlYXR1cmVzOgpFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogU3VwZXJ2aXNvciBNb2RlIEV4ZWN1dGlvbiBQcm90ZWN0aW9uIChTTUVQKSBzdXBwb3J0CmF2YWlsYWJsZTogdmVyPj0zLjAKZW5hYmxlZDogY21kOmdyZXAgLXFpIHNtZXAgL3Byb2MvY3B1aW5mbwphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL3NtZXAubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFN1cGVydmlzb3IgTW9kZSBBY2Nlc3MgUHJldmVudGlvbiAoU01BUCkgc3VwcG9ydAphdmFpbGFibGU6IHZlcj49My43CmVuYWJsZWQ6IGNtZDpncmVwIC1xaSBzbWFwIC9wcm9jL2NwdWluZm8KYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9zbWFwLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpzZWN0aW9uOiAzcmQgcGFydHkga2VybmVsIHByb3RlY3Rpb24gbWVjaGFuaXNtczoKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IEdyc2VjdXJpdHkKYXZhaWxhYmxlOiBDT05GSUdfR1JLRVJOU0VDPXkKZW5hYmxlZDogY21kOnRlc3QgLWMgL2Rldi9ncnNlYwpFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogUGFYCmF2YWlsYWJsZTogQ09ORklHX1BBWD15CmVuYWJsZWQ6IGNtZDp0ZXN0IC14IC9zYmluL3BheGN0bApFT0YKKQoKRkVBVFVSRVNbKChuKyspKV09JChjYXQgPDxFT0YKZmVhdHVyZTogTGludXggS2VybmVsIFJ1bnRpbWUgR3VhcmQgKExLUkcpIGtlcm5lbCBtb2R1bGUKZW5hYmxlZDogY21kOnRlc3QgLWQgL3Byb2Mvc3lzL2xrcmcKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9sa3JnLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpzZWN0aW9uOiBBdHRhY2sgU3VyZmFjZToKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFVzZXIgbmFtZXNwYWNlcyBmb3IgdW5wcml2aWxlZ2VkIGFjY291bnRzCmF2YWlsYWJsZTogQ09ORklHX1VTRVJfTlM9eQplbmFibGVkOiBzeXNjdGw6a2VybmVsLnVucHJpdmlsZWdlZF91c2VybnNfY2xvbmU9PTEKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy91c2VyX25zLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBVbnByaXZpbGVnZWQgYWNjZXNzIHRvIGJwZigpIHN5c3RlbSBjYWxsCmF2YWlsYWJsZTogQ09ORklHX0JQRl9TWVNDQUxMPXkKZW5hYmxlZDogc3lzY3RsOmtlcm5lbC51bnByaXZpbGVnZWRfYnBmX2Rpc2FibGVkIT0xCmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvYnBmX3N5c2NhbGwubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFN5c2NhbGxzIGZpbHRlcmluZwphdmFpbGFibGU6IENPTkZJR19TRUNDT01QPXkKZW5hYmxlZDogY21kOmdyZXAgLWl3IFNlY2NvbXAgL3Byb2Mvc2VsZi9zdGF0dXMgfCBhd2sgJ3twcmludCBcJDJ9JwphbmFseXNpcy11cmw6IGh0dHBzOi8vZ2l0aHViLmNvbS9temV0LS9sZXMtcmVzL2Jsb2IvbWFzdGVyL2ZlYXR1cmVzL2JwZl9zeXNjYWxsLm1kCkVPRgopCgpGRUFUVVJFU1soKG4rKykpXT0kKGNhdCA8PEVPRgpmZWF0dXJlOiBTdXBwb3J0IGZvciAvZGV2L21lbSBhY2Nlc3MKYXZhaWxhYmxlOiBDT05GSUdfREVWTUVNPXkKYW5hbHlzaXMtdXJsOiBodHRwczovL2dpdGh1Yi5jb20vbXpldC0vbGVzLXJlcy9ibG9iL21hc3Rlci9mZWF0dXJlcy9kZXZtZW0ubWQKRU9GCikKCkZFQVRVUkVTWygobisrKSldPSQoY2F0IDw8RU9GCmZlYXR1cmU6IFN1cHBvcnQgZm9yIC9kZXYva21lbSBhY2Nlc3MKYXZhaWxhYmxlOiBDT05GSUdfREVWS01FTT15CmFuYWx5c2lzLXVybDogaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xlcy1yZXMvYmxvYi9tYXN0ZXIvZmVhdHVyZXMvZGV2a21lbS5tZApFT0YKKQoKCnZlcnNpb24oKSB7CiAgICBlY2hvICJsaW51eC1leHBsb2l0LXN1Z2dlc3RlciAiJFZFUlNJT04iLCBtemV0LCBodHRwczovL3otbGFicy5ldSwgTWFyY2ggMjAxOSIKfQoKdXNhZ2UoKSB7CiAgICBlY2hvICJMRVMgdmVyLiAkVkVSU0lPTiAoaHR0cHM6Ly9naXRodWIuY29tL216ZXQtL2xpbnV4LWV4cGxvaXQtc3VnZ2VzdGVyKSBieSBAX216ZXRfIgogICAgZWNobwogICAgZWNobyAiVXNhZ2U6IGxpbnV4LWV4cGxvaXQtc3VnZ2VzdGVyLnNoIFtPUFRJT05TXSIKICAgIGVjaG8KICAgIGVjaG8gIiAtViB8IC0tdmVyc2lvbiAgICAgICAgICAgICAgIC0gcHJpbnQgdmVyc2lvbiBvZiB0aGlzIHNjcmlwdCIKICAgIGVjaG8gIiAtaCB8IC0taGVscCAgICAgICAgICAgICAgICAgIC0gcHJpbnQgdGhpcyBoZWxwIgogICAgZWNobyAiIC1rIHwgLS1rZXJuZWwgPHZlcnNpb24+ICAgICAgLSBwcm92aWRlIGtlcm5lbCB2ZXJzaW9uIgogICAgZWNobyAiIC11IHwgLS11bmFtZSA8c3RyaW5nPiAgICAgICAgLSBwcm92aWRlICd1bmFtZSAtYScgc3RyaW5nIgogICAgZWNobyAiIC0tc2tpcC1tb3JlLWNoZWNrcyAgICAgICAgICAgLSBkbyBub3QgcGVyZm9ybSBhZGRpdGlvbmFsIGNoZWNrcyAoa2VybmVsIGNvbmZpZywgc3lzY3RsKSB0byBkZXRlcm1pbmUgaWYgZXhwbG9pdCBpcyBhcHBsaWNhYmxlIgogICAgZWNobyAiIC0tc2tpcC1wa2ctdmVyc2lvbnMgICAgICAgICAgLSBza2lwIGNoZWNraW5nIGZvciBleGFjdCB1c2Vyc3BhY2UgcGFja2FnZSB2ZXJzaW9uIChoZWxwcyB0byBhdm9pZCBmYWxzZSBuZWdhdGl2ZXMpIgogICAgZWNobyAiIC1wIHwgLS1wa2dsaXN0LWZpbGUgPGZpbGU+ICAgLSBwcm92aWRlIGZpbGUgd2l0aCAnZHBrZyAtbCcgb3IgJ3JwbSAtcWEnIGNvbW1hbmQgb3V0cHV0IgogICAgZWNobyAiIC0tY3ZlbGlzdC1maWxlIDxmaWxlPiAgICAgICAgLSBwcm92aWRlIGZpbGUgd2l0aCBMaW51eCBrZXJuZWwgQ1ZFcyBsaXN0IgogICAgZWNobyAiIC0tY2hlY2tzZWMgICAgICAgICAgICAgICAgICAgLSBsaXN0IHNlY3VyaXR5IHJlbGF0ZWQgZmVhdHVyZXMgZm9yIHlvdXIgSFcva2VybmVsIgogICAgZWNobyAiIC1zIHwgLS1mZXRjaC1zb3VyY2VzICAgICAgICAgLSBhdXRvbWF0aWNhbGx5IGRvd25sb2FkcyBzb3VyY2UgZm9yIG1hdGNoZWQgZXhwbG9pdCIKICAgIGVjaG8gIiAtYiB8IC0tZmV0Y2gtYmluYXJpZXMgICAgICAgIC0gYXV0b21hdGljYWxseSBkb3dubG9hZHMgYmluYXJ5IGZvciBtYXRjaGVkIGV4cGxvaXQgaWYgYXZhaWxhYmxlIgogICAgZWNobyAiIC1mIHwgLS1mdWxsICAgICAgICAgICAgICAgICAgLSBzaG93IGZ1bGwgaW5mbyBhYm91dCBtYXRjaGVkIGV4cGxvaXQiCiAgICBlY2hvICIgLWcgfCAtLXNob3J0ICAgICAgICAgICAgICAgICAtIHNob3cgc2hvcnRlbiBpbmZvIGFib3V0IG1hdGNoZWQgZXhwbG9pdCIKICAgIGVjaG8gIiAtLWtlcm5lbHNwYWNlLW9ubHkgICAgICAgICAgIC0gc2hvdyBvbmx5IGtlcm5lbCB2dWxuZXJhYmlsaXRpZXMiCiAgICBlY2hvICIgLS11c2Vyc3BhY2Utb25seSAgICAgICAgICAgICAtIHNob3cgb25seSB1c2Vyc3BhY2UgdnVsbmVyYWJpbGl0aWVzIgogICAgZWNobyAiIC1kIHwgLS1zaG93LWRvcyAgICAgICAgICAgICAgLSBzaG93IGFsc28gRG9TZXMgaW4gcmVzdWx0cyIKfQoKZXhpdFdpdGhFcnJNc2coKSB7CiAgICBlY2hvICIkMSIgMT4mMgogICAgZXhpdCAxCn0KCiMgZXh0cmFjdHMgYWxsIGluZm9ybWF0aW9uIGZyb20gb3V0cHV0IG9mICd1bmFtZSAtYScgY29tbWFuZApwYXJzZVVuYW1lKCkgewogICAgbG9jYWwgdW5hbWU9JDEKCiAgICBLRVJORUw9JChlY2hvICIkdW5hbWUiIHwgYXdrICd7cHJpbnQgJDN9JyB8IGN1dCAtZCAnLScgLWYgMSkKICAgIEtFUk5FTF9BTEw9JChlY2hvICIkdW5hbWUiIHwgYXdrICd7cHJpbnQgJDN9JykKICAgIEFSQ0g9JChlY2hvICIkdW5hbWUiIHwgYXdrICd7cHJpbnQgJChORi0xKX0nKQoKICAgIE9TPSIiCiAgICBlY2hvICIkdW5hbWUiIHwgZ3JlcCAtcSAtaSAnZGViJyAmJiBPUz0iZGViaWFuIgogICAgZWNobyAiJHVuYW1lIiB8IGdyZXAgLXEgLWkgJ3VidW50dScgJiYgT1M9InVidW50dSIKICAgIGVjaG8gIiR1bmFtZSIgfCBncmVwIC1xIC1pICdcLUFSQ0gnICYmIE9TPSJhcmNoIgogICAgZWNobyAiJHVuYW1lIiB8IGdyZXAgLXEgLWkgJ1wtZGVlcGluJyAmJiBPUz0iZGVlcGluIgogICAgZWNobyAiJHVuYW1lIiB8IGdyZXAgLXEgLWkgJ1wtTUFOSkFSTycgJiYgT1M9Im1hbmphcm8iCiAgICBlY2hvICIkdW5hbWUiIHwgZ3JlcCAtcSAtaSAnXC5mYycgJiYgT1M9ImZlZG9yYSIKICAgIGVjaG8gIiR1bmFtZSIgfCBncmVwIC1xIC1pICdcLmVsJyAmJiBPUz0iUkhFTCIKICAgIGVjaG8gIiR1bmFtZSIgfCBncmVwIC1xIC1pICdcLm1nYScgJiYgT1M9Im1hZ2VpYSIKCiAgICAjICd1bmFtZSAtYScgb3V0cHV0IGRvZXNuJ3QgY29udGFpbiBkaXN0cmlidXRpb24gbnVtYmVyIChhdCBsZWFzdCBub3QgaW4gY2FzZSBvZiBhbGwgZGlzdHJvcykKfQoKZ2V0UGtnTGlzdCgpIHsKICAgIGxvY2FsIGRpc3Rybz0kMQogICAgbG9jYWwgcGtnbGlzdF9maWxlPSQyCiAgICAKICAgICMgdGFrZSBwYWNrYWdlIGxpc3RpbmcgZnJvbSBwcm92aWRlZCBmaWxlICYgZGV0ZWN0IGlmIGl0J3MgJ3JwbSAtcWEnIGxpc3Rpbmcgb3IgJ2Rwa2cgLWwnIG9yICdwYWNtYW4gLVEnIGxpc3Rpbmcgb2Ygbm90IHJlY29nbml6ZWQgbGlzdGluZwogICAgaWYgWyAiJG9wdF9wa2dsaXN0X2ZpbGUiID0gInRydWUiIC1hIC1lICIkcGtnbGlzdF9maWxlIiBdOyB0aGVuCgogICAgICAgICMgdWJ1bnR1L2RlYmlhbiBwYWNrYWdlIGxpc3RpbmcgZmlsZQogICAgICAgIGlmIFsgJChoZWFkIC0xICIkcGtnbGlzdF9maWxlIiB8IGdyZXAgJ0Rlc2lyZWQ9VW5rbm93bi9JbnN0YWxsL1JlbW92ZS9QdXJnZS9Ib2xkJykgXTsgdGhlbgogICAgICAgICAgICBQS0dfTElTVD0kKGNhdCAiJHBrZ2xpc3RfZmlsZSIgfCBhd2sgJ3twcmludCAkMiItIiQzfScgfCBzZWQgJ3MvOmFtZDY0Ly9nJykKCiAgICAgICAgICAgIE9TPSJkZWJpYW4iCiAgICAgICAgICAgIFsgIiQoZ3JlcCB1YnVudHUgIiRwa2dsaXN0X2ZpbGUiKSIgXSAmJiBPUz0idWJ1bnR1IgogICAgICAgICMgcmVkaGF0IHBhY2thZ2UgbGlzdGluZyBmaWxlCiAgICAgICAgZWxpZiBbICIkKGdyZXAgLUUgJ1wuZWxbMS05XStbXC5fXScgIiRwa2dsaXN0X2ZpbGUiIHwgaGVhZCAtMSkiIF07IHRoZW4KICAgICAgICAgICAgUEtHX0xJU1Q9JChjYXQgIiRwa2dsaXN0X2ZpbGUiKQogICAgICAgICAgICBPUz0iUkhFTCIKICAgICAgICAjIGZlZG9yYSBwYWNrYWdlIGxpc3RpbmcgZmlsZQogICAgICAgIGVsaWYgWyAiJChncmVwIC1FICdcLmZjWzEtOV0rJ2kgIiRwa2dsaXN0X2ZpbGUiIHwgaGVhZCAtMSkiIF07IHRoZW4KICAgICAgICAgICAgUEtHX0xJU1Q9JChjYXQgIiRwa2dsaXN0X2ZpbGUiKQogICAgICAgICAgICBPUz0iZmVkb3JhIgogICAgICAgICMgbWFnZWlhIHBhY2thZ2UgbGlzdGluZyBmaWxlCiAgICAgICAgZWxpZiBbICIkKGdyZXAgLUUgJ1wubWdhWzEtOV0rJyAiJHBrZ2xpc3RfZmlsZSIgfCBoZWFkIC0xKSIgXTsgdGhlbgogICAgICAgICAgICBQS0dfTElTVD0kKGNhdCAiJHBrZ2xpc3RfZmlsZSIpCiAgICAgICAgICAgIE9TPSJtYWdlaWEiCiAgICAgICAgIyBwYWNtYW4gcGFja2FnZSBsaXN0aW5nIGZpbGUKICAgICAgICBlbGlmIFsgIiQoZ3JlcCAtRSAnXCBbMC05XStcLicgIiRwa2dsaXN0X2ZpbGUiIHwgaGVhZCAtMSkiIF07IHRoZW4KICAgICAgICAgICAgUEtHX0xJU1Q9JChjYXQgIiRwa2dsaXN0X2ZpbGUiIHwgYXdrICd7cHJpbnQgJDEiLSIkMn0nKQogICAgICAgICAgICBPUz0iYXJjaCIKICAgICAgICAjIGZpbGUgbm90IHJlY29nbml6ZWQgLSBza2lwcGluZwogICAgICAgIGVsc2UKICAgICAgICAgICAgUEtHX0xJU1Q9IiIKICAgICAgICBmaQoKICAgIGVsaWYgWyAiJGRpc3RybyIgPSAiZGViaWFuIiAtbyAiJGRpc3RybyIgPSAidWJ1bnR1IiAtbyAiJGRpc3RybyIgPSAiZGVlcGluIiBdOyB0aGVuCiAgICAgICAgUEtHX0xJU1Q9JChkcGtnIC1sIHwgYXdrICd7cHJpbnQgJDIiLSIkM30nIHwgc2VkICdzLzphbWQ2NC8vZycpCiAgICBlbGlmIFsgIiRkaXN0cm8iID0gIlJIRUwiIC1vICIkZGlzdHJvIiA9ICJmZWRvcmEiIC1vICIkZGlzdHJvIiA9ICJtYWdlaWEiIF07IHRoZW4KICAgICAgICBQS0dfTElTVD0kKHJwbSAtcWEpCiAgICBlbGlmIFsgIiRkaXN0cm8iID0gImFyY2giIC1vICIkZGlzdHJvIiA9ICJtYW5qYXJvIiBdOyB0aGVuCiAgICAgICAgUEtHX0xJU1Q9JChwYWNtYW4gLVEgfCBhd2sgJ3twcmludCAkMSItIiQyfScpCiAgICBlbGlmIFsgLXggL3Vzci9iaW4vZXF1ZXJ5IF07IHRoZW4KICAgICAgICBQS0dfTElTVD0kKC91c3IvYmluL2VxdWVyeSAtLXF1aWV0IGxpc3QgJyonIC1GICckbmFtZTokdmVyc2lvbicgfCBjdXQgLWQvIC1mMi0gfCBhd2sgJ3twcmludCAkMSI6IiQyfScpCiAgICBlbHNlCiAgICAgICAgIyBwYWNrYWdlcyBsaXN0aW5nIG5vdCBhdmFpbGFibGUKICAgICAgICBQS0dfTElTVD0iIgogICAgZmkKfQoKIyBmcm9tOiBodHRwczovL3N0YWNrb3ZlcmZsb3cuY29tL3F1ZXN0aW9ucy80MDIzODMwL2hvdy1jb21wYXJlLXR3by1zdHJpbmdzLWluLWRvdC1zZXBhcmF0ZWQtdmVyc2lvbi1mb3JtYXQtaW4tYmFzaAp2ZXJDb21wYXJpc2lvbigpIHsKCiAgICBpZiBbWyAkMSA9PSAkMiBdXQogICAgdGhlbgogICAgICAgIHJldHVybiAwCiAgICBmaQoKICAgIGxvY2FsIElGUz0uCiAgICBsb2NhbCBpIHZlcjE9KCQxKSB2ZXIyPSgkMikKCiAgICAjIGZpbGwgZW1wdHkgZmllbGRzIGluIHZlcjEgd2l0aCB6ZXJvcwogICAgZm9yICgoaT0keyN2ZXIxW0BdfTsgaTwkeyN2ZXIyW0BdfTsgaSsrKSkKICAgIGRvCiAgICAgICAgdmVyMVtpXT0wCiAgICBkb25lCgogICAgZm9yICgoaT0wOyBpPCR7I3ZlcjFbQF19OyBpKyspKQogICAgZG8KICAgICAgICBpZiBbWyAteiAke3ZlcjJbaV19IF1dCiAgICAgICAgdGhlbgogICAgICAgICAgICAjIGZpbGwgZW1wdHkgZmllbGRzIGluIHZlcjIgd2l0aCB6ZXJvcwogICAgICAgICAgICB2ZXIyW2ldPTAKICAgICAgICBmaQogICAgICAgIGlmICgoMTAjJHt2ZXIxW2ldfSA+IDEwIyR7dmVyMltpXX0pKQogICAgICAgIHRoZW4KICAgICAgICAgICAgcmV0dXJuIDEKICAgICAgICBmaQogICAgICAgIGlmICgoMTAjJHt2ZXIxW2ldfSA8IDEwIyR7dmVyMltpXX0pKQogICAgICAgIHRoZW4KICAgICAgICAgICAgcmV0dXJuIDIKICAgICAgICBmaQogICAgZG9uZQoKICAgIHJldHVybiAwCn0KCmRvVmVyc2lvbkNvbXBhcmlzaW9uKCkgewogICAgbG9jYWwgcmVxVmVyc2lvbj0iJDEiCiAgICBsb2NhbCByZXFSZWxhdGlvbj0iJDIiCiAgICBsb2NhbCBjdXJyZW50VmVyc2lvbj0iJDMiCgogICAgdmVyQ29tcGFyaXNpb24gJGN1cnJlbnRWZXJzaW9uICRyZXFWZXJzaW9uCiAgICBjYXNlICQ/IGluCiAgICAgICAgMCkgY3VycmVudFJlbGF0aW9uPSc9Jzs7CiAgICAgICAgMSkgY3VycmVudFJlbGF0aW9uPSc+Jzs7CiAgICAgICAgMikgY3VycmVudFJlbGF0aW9uPSc8Jzs7CiAgICBlc2FjCgogICAgaWYgWyAiJHJlcVJlbGF0aW9uIiA9PSAiPSIgXTsgdGhlbgogICAgICAgIFsgJGN1cnJlbnRSZWxhdGlvbiA9PSAiPSIgXSAmJiByZXR1cm4gMAogICAgZWxpZiBbICIkcmVxUmVsYXRpb24iID09ICI+IiBdOyB0aGVuCiAgICAgICAgWyAkY3VycmVudFJlbGF0aW9uID09ICI+IiBdICYmIHJldHVybiAwCiAgICBlbGlmIFsgIiRyZXFSZWxhdGlvbiIgPT0gIjwiIF07IHRoZW4KICAgICAgICBbICRjdXJyZW50UmVsYXRpb24gPT0gIjwiIF0gJiYgcmV0dXJuIDAKICAgIGVsaWYgWyAiJHJlcVJlbGF0aW9uIiA9PSAiPj0iIF07IHRoZW4KICAgICAgICBbICRjdXJyZW50UmVsYXRpb24gPT0gIj0iIF0gJiYgcmV0dXJuIDAKICAgICAgICBbICRjdXJyZW50UmVsYXRpb24gPT0gIj4iIF0gJiYgcmV0dXJuIDAKICAgIGVsaWYgWyAiJHJlcVJlbGF0aW9uIiA9PSAiPD0iIF07IHRoZW4KICAgICAgICBbICRjdXJyZW50UmVsYXRpb24gPT0gIj0iIF0gJiYgcmV0dXJuIDAKICAgICAgICBbICRjdXJyZW50UmVsYXRpb24gPT0gIjwiIF0gJiYgcmV0dXJuIDAKICAgIGZpCn0KCmNvbXBhcmVWYWx1ZXMoKSB7CiAgICBjdXJWYWw9JDEKICAgIHZhbD0kMgogICAgc2lnbj0kMwoKICAgIGlmIFsgIiRzaWduIiA9PSAiPT0iIF07IHRoZW4KICAgICAgICBbICIkdmFsIiA9PSAiJGN1clZhbCIgXSAmJiByZXR1cm4gMAogICAgZWxpZiBbICIkc2lnbiIgPT0gIiE9IiBdOyB0aGVuCiAgICAgICAgWyAiJHZhbCIgIT0gIiRjdXJWYWwiIF0gJiYgcmV0dXJuIDAKICAgIGZpCgogICAgcmV0dXJuIDEKfQoKY2hlY2tSZXF1aXJlbWVudCgpIHsKICAgICNlY2hvICJDaGVja2luZyByZXF1aXJlbWVudDogJDEiCiAgICBsb2NhbCBJTj0iJDEiCiAgICBsb2NhbCBwa2dOYW1lPSIkezI6NH0iCgogICAgaWYgW1sgIiRJTiIgPX4gXnBrZz0uKiQgXV07IHRoZW4KCiAgICAgICAgIyBhbHdheXMgdHJ1ZSBmb3IgTGludXggT1MKICAgICAgICBbICR7cGtnTmFtZX0gPT0gImxpbnV4LWtlcm5lbCIgXSAmJiByZXR1cm4gMAoKICAgICAgICAjIHZlcmlmeSBpZiBwYWNrYWdlIGlzIHByZXNlbnQgCiAgICAgICAgcGtnPSQoZWNobyAiJFBLR19MSVNUIiB8IGdyZXAgLUUgLWkgIl4kcGtnTmFtZS1bMC05XSsiIHwgaGVhZCAtMSkKICAgICAgICBpZiBbIC1uICIkcGtnIiBdOyB0aGVuCiAgICAgICAgICAgIHJldHVybiAwCiAgICAgICAgZmkKCiAgICBlbGlmIFtbICIkSU4iID1+IF52ZXIuKiQgXV07IHRoZW4KICAgICAgICB2ZXJzaW9uPSIke0lOLy9bXjAtOS5dL30iCiAgICAgICAgcmVzdD0iJHtJTiN2ZXJ9IgogICAgICAgIG9wZXJhdG9yPSR7cmVzdCUkdmVyc2lvbn0KCiAgICAgICAgaWYgWyAiJHBrZ05hbWUiID09ICJsaW51eC1rZXJuZWwiIC1vICIkb3B0X2NoZWNrc2VjX21vZGUiID09ICJ0cnVlIiBdOyB0aGVuCgogICAgICAgICAgICAjIGZvciAtLWN2ZWxpc3QtZmlsZSBtb2RlIHNraXAga2VybmVsIHZlcnNpb24gY29tcGFyaXNpb24KICAgICAgICAgICAgWyAiJG9wdF9jdmVsaXN0X2ZpbGUiID0gInRydWUiIF0gJiYgcmV0dXJuIDAKCiAgICAgICAgICAgIGRvVmVyc2lvbkNvbXBhcmlzaW9uICR2ZXJzaW9uICRvcGVyYXRvciAkS0VSTkVMICYmIHJldHVybiAwCiAgICAgICAgZWxzZQogICAgICAgICAgICAjIGV4dHJhY3QgcGFja2FnZSB2ZXJzaW9uIGFuZCBjaGVjayBpZiByZXF1aXJlbW50IGlzIHRydWUKICAgICAgICAgICAgcGtnPSQoZWNobyAiJFBLR19MSVNUIiB8IGdyZXAgLUUgLWkgIl4kcGtnTmFtZS1bMC05XSsiIHwgaGVhZCAtMSkKCiAgICAgICAgICAgICMgc2tpcCAoaWYgcnVuIHdpdGggLS1za2lwLXBrZy12ZXJzaW9ucykgdmVyc2lvbiBjaGVja2luZyBpZiBwYWNrYWdlIHdpdGggZ2l2ZW4gbmFtZSBpcyBpbnN0YWxsZWQKICAgICAgICAgICAgWyAiJG9wdF9za2lwX3BrZ192ZXJzaW9ucyIgPSAidHJ1ZSIgLWEgLW4gIiRwa2ciIF0gJiYgcmV0dXJuIDAKCiAgICAgICAgICAgICMgdmVyc2lvbmluZzoKICAgICAgICAgICAgI2VjaG8gInBrZzogJHBrZyIKICAgICAgICAgICAgcGtnVmVyc2lvbj0kKGVjaG8gIiRwa2ciIHwgZ3JlcCAtRSAtaSAtbyAtZSAnLVtcLjAtOVwrOnBdK1stXCtdJyB8IGN1dCAtZCc6JyAtZjIgfCBzZWQgJ3MvW1wrLV0vL2cnIHwgc2VkICdzL3BbMC05XS8vZycpCiAgICAgICAgICAgICNlY2hvICJ2ZXJzaW9uOiAkcGtnVmVyc2lvbiIKICAgICAgICAgICAgI2VjaG8gIm9wZXJhdG9yOiAkb3BlcmF0b3IiCiAgICAgICAgICAgICNlY2hvICJyZXF1aXJlZCB2ZXJzaW9uOiAkdmVyc2lvbiIKICAgICAgICAgICAgI2VjaG8KICAgICAgICAgICAgZG9WZXJzaW9uQ29tcGFyaXNpb24gJHZlcnNpb24gJG9wZXJhdG9yICRwa2dWZXJzaW9uICYmIHJldHVybiAwCiAgICAgICAgZmkKICAgIGVsaWYgW1sgIiRJTiIgPX4gXng4Nl82NCQgXV0gJiYgWyAiJEFSQ0giID09ICJ4ODZfNjQiIC1vICIkQVJDSCIgPT0gIiIgXTsgdGhlbgogICAgICAgIHJldHVybiAwCiAgICBlbGlmIFtbICIkSU4iID1+IF54ODYkIF1dICYmIFsgIiRBUkNIIiA9PSAiaTM4NiIgLW8gIiRBUkNIIiA9PSAiaTY4NiIgLW8gIiRBUkNIIiA9PSAiIiBdOyB0aGVuCiAgICAgICAgcmV0dXJuIDAKICAgIGVsaWYgW1sgIiRJTiIgPX4gXkNPTkZJR18uKiQgXV07IHRoZW4KCiAgICAgICAgIyBza2lwIGlmIGNoZWNrIGlzIG5vdCBhcHBsaWNhYmxlICgtayBvciAtLXVuYW1lIG9yIC1wIHNldCkgb3IgaWYgdXNlciBzYWlkIHNvICgtLXNraXAtbW9yZS1jaGVja3MpCiAgICAgICAgWyAiJG9wdF9za2lwX21vcmVfY2hlY2tzIiA9ICJ0cnVlIiBdICYmIHJldHVybiAwCgogICAgICAgICMgaWYga2VybmVsIGNvbmZpZyBJUyBhdmFpbGFibGU6CiAgICAgICAgaWYgWyAtbiAiJEtDT05GSUciIF07IHRoZW4KICAgICAgICAgICAgaWYgJEtDT05GSUcgfCBncmVwIC1FIC1xaSAkSU47IHRoZW4KICAgICAgICAgICAgICAgIHJldHVybiAwOwogICAgICAgICAgICAjIHJlcXVpcmVkIG9wdGlvbiB3YXNuJ3QgZm91bmQsIGV4cGxvaXQgaXMgbm90IGFwcGxpY2FibGUKICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgcmV0dXJuIDE7CiAgICAgICAgICAgIGZpCiAgICAgICAgIyBjb25maWcgaXMgbm90IGF2YWlsYWJsZQogICAgICAgIGVsc2UKICAgICAgICAgICAgcmV0dXJuIDA7CiAgICAgICAgZmkKICAgIGVsaWYgW1sgIiRJTiIgPX4gXnN5c2N0bDouKiQgXV07IHRoZW4KCiAgICAgICAgIyBza2lwIGlmIGNoZWNrIGlzIG5vdCBhcHBsaWNhYmxlICgtayBvciAtLXVuYW1lIG9yIC1wIG1vZGVzKSBvciBpZiB1c2VyIHNhaWQgc28gKC0tc2tpcC1tb3JlLWNoZWNrcykKICAgICAgICBbICIkb3B0X3NraXBfbW9yZV9jaGVja3MiID0gInRydWUiIF0gJiYgcmV0dXJuIDAKCiAgICAgICAgc3lzY3RsQ29uZGl0aW9uPSIke0lOOjd9IgoKICAgICAgICAjIGV4dHJhY3Qgc3lzY3RsIGVudHJ5LCByZWxhdGlvbiBzaWduIGFuZCByZXF1aXJlZCB2YWx1ZQogICAgICAgIGlmIGVjaG8gJHN5c2N0bENvbmRpdGlvbiB8IGdyZXAgLXFpICIhPSI7IHRoZW4KICAgICAgICAgICAgc2lnbj0iIT0iCiAgICAgICAgZWxpZiBlY2hvICRzeXNjdGxDb25kaXRpb24gfCBncmVwIC1xaSAiPT0iOyB0aGVuCiAgICAgICAgICAgIHNpZ249Ij09IgogICAgICAgIGVsc2UKICAgICAgICAgICAgZXhpdFdpdGhFcnJNc2cgIldyb25nIHN5c2N0bCBjb25kaXRpb24uIFRoZXJlIGlzIHN5bnRheCBlcnJvciBpbiB5b3VyIGZlYXR1cmVzIERCLiBBYm9ydGluZy4iCiAgICAgICAgZmkKICAgICAgICB2YWw9JChlY2hvICIkc3lzY3RsQ29uZGl0aW9uIiB8IGF3ayAtRiAiJHNpZ24iICd7cHJpbnQgJDJ9JykKICAgICAgICBlbnRyeT0kKGVjaG8gIiRzeXNjdGxDb25kaXRpb24iIHwgYXdrIC1GICIkc2lnbiIgJ3twcmludCAkMX0nKQoKICAgICAgICAjIGdldCBjdXJyZW50IHNldHRpbmcgb2Ygc3lzY3RsIGVudHJ5CiAgICAgICAgY3VyVmFsPSQoL3NiaW4vc3lzY3RsIC1hIDI+IC9kZXYvbnVsbCB8IGdyZXAgIiRlbnRyeSIgfCBhd2sgLUYnPScgJ3twcmludCAkMn0nKQoKICAgICAgICAjIHNwZWNpYWwgY2FzZSBmb3IgLS1jaGVja3NlYyBtb2RlOiByZXR1cm4gMiBpZiB0aGVyZSBpcyBubyBzdWNoIHN3aXRjaCBpbiBzeXNjdGwKICAgICAgICBbIC16ICIkY3VyVmFsIiAtYSAiJG9wdF9jaGVja3NlY19tb2RlIiA9ICJ0cnVlIiBdICYmIHJldHVybiAyCgogICAgICAgICMgZm9yIG90aGVyIG1vZGVzOiBza2lwIGlmIHRoZXJlIGlzIG5vIHN1Y2ggc3dpdGNoIGluIHN5c2N0bAogICAgICAgIFsgLXogIiRjdXJWYWwiIF0gJiYgcmV0dXJuIDAKCiAgICAgICAgIyBjb21wYXJlICYgcmV0dXJuIHJlc3VsdAogICAgICAgIGNvbXBhcmVWYWx1ZXMgJGN1clZhbCAkdmFsICRzaWduICYmIHJldHVybiAwCgogICAgZWxpZiBbWyAiJElOIiA9fiBeY21kOi4qJCBdXTsgdGhlbgoKICAgICAgICAjIHNraXAgaWYgY2hlY2sgaXMgbm90IGFwcGxpY2FibGUgKC1rIG9yIC0tdW5hbWUgb3IgLXAgbW9kZXMpIG9yIGlmIHVzZXIgc2FpZCBzbyAoLS1za2lwLW1vcmUtY2hlY2tzKQogICAgICAgIFsgIiRvcHRfc2tpcF9tb3JlX2NoZWNrcyIgPSAidHJ1ZSIgXSAmJiByZXR1cm4gMAoKICAgICAgICBjbWQ9IiR7SU46NH0iCiAgICAgICAgaWYgZXZhbCAiJHtjbWR9IjsgdGhlbgogICAgICAgICAgICByZXR1cm4gMAogICAgICAgIGZpCiAgICBmaQoKICAgIHJldHVybiAxCn0KCmdldEtlcm5lbENvbmZpZygpIHsKCiAgICBpZiBbIC1mIC9wcm9jL2NvbmZpZy5neiBdIDsgdGhlbgogICAgICAgIEtDT05GSUc9InpjYXQgL3Byb2MvY29uZmlnLmd6IgogICAgZWxpZiBbIC1mIC9ib290L2NvbmZpZy1gdW5hbWUgLXJgIF0gOyB0aGVuCiAgICAgICAgS0NPTkZJRz0iY2F0IC9ib290L2NvbmZpZy1gdW5hbWUgLXJgIgogICAgZWxpZiBbIC1mICIke0tCVUlMRF9PVVRQVVQ6LS91c3Ivc3JjL2xpbnV4fSIvLmNvbmZpZyBdIDsgdGhlbgogICAgICAgIEtDT05GSUc9ImNhdCAke0tCVUlMRF9PVVRQVVQ6LS91c3Ivc3JjL2xpbnV4fS8uY29uZmlnIgogICAgZWxzZQogICAgICAgIEtDT05GSUc9IiIKICAgIGZpCn0KCmNoZWNrc2VjTW9kZSgpIHsKCiAgICBNT0RFPTAKCiAgICAjIHN0YXJ0IGFuYWx5c2lzCmZvciBGRUFUVVJFIGluICIke0ZFQVRVUkVTW0BdfSI7IGRvCgogICAgIyBjcmVhdGUgYXJyYXkgZnJvbSBjdXJyZW50IGV4cGxvaXQgaGVyZSBkb2MgYW5kIGZldGNoIG5lZWRlZCBsaW5lcwogICAgaT0wCiAgICAjICgnLXInIGlzIHVzZWQgdG8gbm90IGludGVycHJldCBiYWNrc2xhc2ggdXNlZCBmb3IgYmFzaCBjb2xvcnMpCiAgICB3aGlsZSByZWFkIC1yIGxpbmUKICAgIGRvCiAgICAgICAgYXJyW2ldPSIkbGluZSIKICAgICAgICBpPSQoKGkgKyAxKSkKICAgIGRvbmUgPDw8ICIkRkVBVFVSRSIKCgkjIG1vZGVzOiBrZXJuZWwtZmVhdHVyZSAoMSkgfCBody1mZWF0dXJlICgyKSB8IDNyZHBhcnR5LWZlYXR1cmUgKDMpIHwgYXR0YWNrLXN1cmZhY2UgKDQpCiAgICBOQU1FPSIke2FyclswXX0iCiAgICBQUkVfTkFNRT0iJHtOQU1FOjA6OH0iCiAgICBOQU1FPSIke05BTUU6OX0iCiAgICBpZiBbICIke1BSRV9OQU1FfSIgPSAic2VjdGlvbjoiIF07IHRoZW4KCQkjIGFkdmFuY2UgdG8gbmV4dCBNT0RFCgkJTU9ERT0kKCgkTU9ERSArIDEpKQoKICAgICAgICBlY2hvCiAgICAgICAgZWNobyAtZSAiJHtibGR3aHR9JHtOQU1FfSR7dHh0cnN0fSIKICAgICAgICBlY2hvCiAgICAgICAgY29udGludWUKICAgIGZpCgogICAgQVZBSUxBQkxFPSIke2FyclsxXX0iICYmIEFWQUlMQUJMRT0iJHtBVkFJTEFCTEU6MTF9IgogICAgRU5BQkxFPSQoZWNobyAiJEZFQVRVUkUiIHwgZ3JlcCAiZW5hYmxlZDogIiB8IGF3ayAtRidlZDogJyAne3ByaW50ICQyfScpCiAgICBhbmFseXNpc191cmw9JChlY2hvICIkRkVBVFVSRSIgfCBncmVwICJhbmFseXNpcy11cmw6ICIgfCBhd2sgJ3twcmludCAkMn0nKQoKICAgICMgc3BsaXQgbGluZSB3aXRoIGF2YWlsYWJpbGl0eSByZXF1aXJlbWVudHMgJiBsb29wIHRocnUgYWxsIGF2YWlsYWJpbGl0eSByZXFzIG9uZSBieSBvbmUgJiBjaGVjayB3aGV0aGVyIGl0IGlzIG1ldAogICAgSUZTPScsJyByZWFkIC1yIC1hIGFycmF5IDw8PCAiJEFWQUlMQUJMRSIKICAgIEFWQUlMQUJMRV9SRVFTX05VTT0keyNhcnJheVtAXX0KICAgIEFWQUlMQUJMRV9QQVNTRURfUkVRPTAKCUNPTkZJRz0iIgogICAgZm9yIFJFUSBpbiAiJHthcnJheVtAXX0iOyBkbwoKCQkjIGZpbmQgQ09ORklHXyBuYW1lIChpZiBwcmVzZW50KSBmb3IgY3VycmVudCBmZWF0dXJlIChvbmx5IGZvciBkaXNwbGF5IHB1cnBvc2VzKQoJCWlmIFsgLXogIiRDT05GSUciIF07IHRoZW4KCQkJY29uZmlnPSQoZWNobyAiJFJFUSIgfCBncmVwICJDT05GSUdfIikKCQkJWyAtbiAiJGNvbmZpZyIgXSAmJiBDT05GSUc9IigkKGVjaG8gJFJFUSB8IGN1dCAtZCc9JyAtZjEpKSIKCQlmaQoKICAgICAgICBpZiAoY2hlY2tSZXF1aXJlbWVudCAiJFJFUSIpOyB0aGVuCiAgICAgICAgICAgIEFWQUlMQUJMRV9QQVNTRURfUkVRPSQoKCRBVkFJTEFCTEVfUEFTU0VEX1JFUSArIDEpKQogICAgICAgIGVsc2UKICAgICAgICAgICAgYnJlYWsKICAgICAgICBmaQogICAgZG9uZQoKICAgICMgc3BsaXQgbGluZSB3aXRoIGVuYWJsZW1lbnQgcmVxdWlyZW1lbnRzICYgbG9vcCB0aHJ1IGFsbCBlbmFibGVtZW50IHJlcXMgb25lIGJ5IG9uZSAmIGNoZWNrIHdoZXRoZXIgaXQgaXMgbWV0CiAgICBFTkFCTEVfUEFTU0VEX1JFUT0wCiAgICBFTkFCTEVfUkVRU19OVU09MAogICAgbm9TeXNjdGw9MAogICAgaWYgWyAtbiAiJEVOQUJMRSIgXTsgdGhlbgogICAgICAgIElGUz0nLCcgcmVhZCAtciAtYSBhcnJheSA8PDwgIiRFTkFCTEUiCiAgICAgICAgRU5BQkxFX1JFUVNfTlVNPSR7I2FycmF5W0BdfQogICAgICAgIGZvciBSRVEgaW4gIiR7YXJyYXlbQF19IjsgZG8KICAgICAgICAgICAgY21kU3Rkb3V0PSQoY2hlY2tSZXF1aXJlbWVudCAiJFJFUSIpCiAgICAgICAgICAgIHJldFZhbD0kPwogICAgICAgICAgICBpZiBbICRyZXRWYWwgLWVxIDAgXTsgdGhlbgogICAgICAgICAgICAgICAgRU5BQkxFX1BBU1NFRF9SRVE9JCgoJEVOQUJMRV9QQVNTRURfUkVRICsgMSkpCiAgICAgICAgICAgIGVsaWYgWyAkcmV0VmFsIC1lcSAyIF07IHRoZW4KICAgICAgICAgICAgIyBzcGVjaWFsIGNhc2U6IHN5c2N0bCBlbnRyeSBpcyBub3QgcHJlc2VudCBvbiBnaXZlbiBzeXN0ZW06IHNpZ25hbCBpdCBhczogTi9BCiAgICAgICAgICAgICAgICBub1N5c2N0bD0xCiAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICBmaQogICAgICAgIGRvbmUKICAgIGZpCgogICAgZmVhdHVyZT0kKGVjaG8gIiRGRUFUVVJFIiB8IGdyZXAgImZlYXR1cmU6ICIgfCBjdXQgLWQnICcgLWYgMi0pCgogICAgaWYgWyAtbiAiJGNtZFN0ZG91dCIgXTsgdGhlbgogICAgICAgIGlmIFsgJGNtZFN0ZG91dCAtZXEgMCBdOyB0aGVuCiAgICAgICAgICAgIHN0YXRlPSJbICR7dHh0cmVkfVNldCB0byAkY21kU3Rkb3V0JHt0eHRyc3R9IF0iCgkJCWNtZFN0ZG91dD0iIgogICAgICAgIGVsc2UKICAgICAgICAgICAgc3RhdGU9IlsgJHt0eHRncm59U2V0IHRvICRjbWRTdGRvdXQke3R4dHJzdH0gXSIKCQkJY21kU3Rkb3V0PSIiCiAgICAgICAgZmkKICAgIGVsc2UKCgl1bmtub3duPSJbICR7dHh0Z3JheX1Vbmtub3duJHt0eHRyc3R9ICBdIgoKCSMgZm9yIDNyZCBwYXJ0eSAoMykgbW9kZSBkaXNwbGF5ICJOL0EiIG9yICJFbmFibGVkIgoJaWYgWyAkTU9ERSAtZXEgMyBdOyB0aGVuCiAgICAgICAgICAgIGVuYWJsZWQ9IlsgJHt0eHRncm59RW5hYmxlZCR7dHh0cnN0fSAgIF0iCiAgICAgICAgICAgIGRpc2FibGVkPSJbICAgJHt0eHRncmF5fU4vQSR7dHh0cnN0fSAgICBdIgoKICAgICAgICAjIGZvciBhdHRhY2stc3VyZmFjZSAoNCkgbW9kZSBkaXNwbGF5ICJMb2NrZWQiIG9yICJFeHBvc2VkIgogICAgICAgIGVsaWYgWyAkTU9ERSAtZXEgNCBdOyB0aGVuCiAgICAgICAgICAgZW5hYmxlZD0iWyAke3R4dHJlZH1FeHBvc2VkJHt0eHRyc3R9ICBdIgogICAgICAgICAgIGRpc2FibGVkPSJbICR7dHh0Z3JufUxvY2tlZCR7dHh0cnN0fSAgIF0iCgoJIyBvdGhlciBtb2RlcyIgIkRpc2FibGVkIiAvICJFbmFibGVkIgoJZWxzZQoJCWVuYWJsZWQ9IlsgJHt0eHRncm59RW5hYmxlZCR7dHh0cnN0fSAgXSIKCQlkaXNhYmxlZD0iWyAke3R4dHJlZH1EaXNhYmxlZCR7dHh0cnN0fSBdIgoJZmkKCglpZiBbIC16ICIkS0NPTkZJRyIgLWEgIiRFTkFCTEVfUkVRU19OVU0iID0gMCBdOyB0aGVuCgkgICAgc3RhdGU9JHVua25vd24KICAgIGVsaWYgWyAkQVZBSUxBQkxFX1BBU1NFRF9SRVEgLWVxICRBVkFJTEFCTEVfUkVRU19OVU0gLWEgJEVOQUJMRV9QQVNTRURfUkVRIC1lcSAkRU5BQkxFX1JFUVNfTlVNIF07IHRoZW4KICAgICAgICBzdGF0ZT0kZW5hYmxlZAogICAgZWxzZQogICAgICAgIHN0YXRlPSRkaXNhYmxlZAoJZmkKCiAgICBmaQoKICAgIGVjaG8gLWUgIiAkc3RhdGUgJGZlYXR1cmUgJHt3aHR9JHtDT05GSUd9JHt0eHRyc3R9IgogICAgWyAtbiAiJGFuYWx5c2lzX3VybCIgXSAmJiBlY2hvIC1lICIgICAgICAgICAgICAgICRhbmFseXNpc191cmwiCiAgICBlY2hvCgpkb25lCgp9CgpkaXNwbGF5RXhwb3N1cmUoKSB7CiAgICBSQU5LPSQxCgogICAgaWYgWyAiJFJBTksiIC1nZSA2IF07IHRoZW4KICAgICAgICBlY2hvICJoaWdobHkgcHJvYmFibGUiCiAgICBlbGlmIFsgIiRSQU5LIiAtZ2UgMyBdOyB0aGVuCiAgICAgICAgZWNobyAicHJvYmFibGUiCiAgICBlbHNlCiAgICAgICAgZWNobyAibGVzcyBwcm9iYWJsZSIKICAgIGZpCn0KCiMgcGFyc2UgY29tbWFuZCBsaW5lIHBhcmFtZXRlcnMKQVJHUz0kKGdldG9wdCAtLW9wdGlvbnMgJFNIT1JUT1BUUyAgLS1sb25nb3B0aW9ucyAkTE9OR09QVFMgLS0gIiRAIikKWyAkPyAhPSAwIF0gJiYgZXhpdFdpdGhFcnJNc2cgIkFib3J0aW5nLiIKCmV2YWwgc2V0IC0tICIkQVJHUyIKCndoaWxlIHRydWU7IGRvCiAgICBjYXNlICIkMSIgaW4KICAgICAgICAtdXwtLXVuYW1lKQogICAgICAgICAgICBzaGlmdAogICAgICAgICAgICBVTkFNRV9BPSIkMSIKICAgICAgICAgICAgb3B0X3VuYW1lX3N0cmluZz10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLVZ8LS12ZXJzaW9uKQogICAgICAgICAgICB2ZXJzaW9uCiAgICAgICAgICAgIGV4aXQgMAogICAgICAgICAgICA7OwogICAgICAgIC1ofC0taGVscCkKICAgICAgICAgICAgdXNhZ2UgCiAgICAgICAgICAgIGV4aXQgMAogICAgICAgICAgICA7OwogICAgICAgIC1mfC0tZnVsbCkKICAgICAgICAgICAgb3B0X2Z1bGw9dHJ1ZQogICAgICAgICAgICA7OwogICAgICAgIC1nfC0tc2hvcnQpCiAgICAgICAgICAgIG9wdF9zdW1tYXJ5PXRydWUKICAgICAgICAgICAgOzsKICAgICAgICAtYnwtLWZldGNoLWJpbmFyaWVzKQogICAgICAgICAgICBvcHRfZmV0Y2hfYmlucz10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLXN8LS1mZXRjaC1zb3VyY2VzKQogICAgICAgICAgICBvcHRfZmV0Y2hfc3Jjcz10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLWt8LS1rZXJuZWwpCiAgICAgICAgICAgIHNoaWZ0CiAgICAgICAgICAgIEtFUk5FTD0iJDEiCiAgICAgICAgICAgIG9wdF9rZXJuZWxfdmVyc2lvbj10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLWR8LS1zaG93LWRvcykKICAgICAgICAgICAgb3B0X3Nob3dfZG9zPXRydWUKICAgICAgICAgICAgOzsKICAgICAgICAtcHwtLXBrZ2xpc3QtZmlsZSkKICAgICAgICAgICAgc2hpZnQKICAgICAgICAgICAgUEtHTElTVF9GSUxFPSIkMSIKICAgICAgICAgICAgb3B0X3BrZ2xpc3RfZmlsZT10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLS1jdmVsaXN0LWZpbGUpCiAgICAgICAgICAgIHNoaWZ0CiAgICAgICAgICAgIENWRUxJU1RfRklMRT0iJDEiCiAgICAgICAgICAgIG9wdF9jdmVsaXN0X2ZpbGU9dHJ1ZQogICAgICAgICAgICA7OwogICAgICAgIC0tY2hlY2tzZWMpCiAgICAgICAgICAgIG9wdF9jaGVja3NlY19tb2RlPXRydWUKICAgICAgICAgICAgOzsKICAgICAgICAtLWtlcm5lbHNwYWNlLW9ubHkpCiAgICAgICAgICAgIG9wdF9rZXJuZWxfb25seT10cnVlCiAgICAgICAgICAgIDs7CiAgICAgICAgLS11c2Vyc3BhY2Utb25seSkKICAgICAgICAgICAgb3B0X3VzZXJzcGFjZV9vbmx5PXRydWUKICAgICAgICAgICAgOzsKICAgICAgICAtLXNraXAtbW9yZS1jaGVja3MpCiAgICAgICAgICAgIG9wdF9za2lwX21vcmVfY2hlY2tzPXRydWUKICAgICAgICAgICAgOzsKICAgICAgICAtLXNraXAtcGtnLXZlcnNpb25zKQogICAgICAgICAgICBvcHRfc2tpcF9wa2dfdmVyc2lvbnM9dHJ1ZQogICAgICAgICAgICA7OwogICAgICAgICopCiAgICAgICAgICAgIHNoaWZ0CiAgICAgICAgICAgIGlmIFsgIiQjIiAhPSAiMCIgXTsgdGhlbgogICAgICAgICAgICAgICAgZXhpdFdpdGhFcnJNc2cgIlVua25vd24gb3B0aW9uICckMScuIEFib3J0aW5nLiIKICAgICAgICAgICAgZmkKICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgOzsKICAgIGVzYWMKICAgIHNoaWZ0CmRvbmUKCiMgY2hlY2sgQmFzaCB2ZXJzaW9uIChhc3NvY2lhdGl2ZSBhcnJheXMgbmVlZCBCYXNoIGluIHZlcnNpb24gNC4wKykKaWYgKChCQVNIX1ZFUlNJTkZPWzBdIDwgNCkpOyB0aGVuCiAgICBleGl0V2l0aEVyck1zZyAiU2NyaXB0IG5lZWRzIEJhc2ggaW4gdmVyc2lvbiA0LjAgb3IgbmV3ZXIuIEFib3J0aW5nLiIKZmkKCiMgZXhpdCBpZiBib3RoIC0ta2VybmVsIGFuZCAtLXVuYW1lIGFyZSBzZXQKWyAiJG9wdF9rZXJuZWxfdmVyc2lvbiIgPSAidHJ1ZSIgXSAmJiBbICRvcHRfdW5hbWVfc3RyaW5nID0gInRydWUiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlN3aXRjaGVzIC11fC0tdW5hbWUgYW5kIC1rfC0ta2VybmVsIGFyZSBtdXR1YWxseSBleGNsdXNpdmUuIEFib3J0aW5nLiIKCiMgZXhpdCBpZiBib3RoIC0tZnVsbCBhbmQgLS1zaG9ydCBhcmUgc2V0ClsgIiRvcHRfZnVsbCIgPSAidHJ1ZSIgXSAmJiBbICRvcHRfc3VtbWFyeSA9ICJ0cnVlIiBdICYmIGV4aXRXaXRoRXJyTXNnICJTd2l0Y2hlcyAtZnwtLWZ1bGwgYW5kIC1nfC0tc2hvcnQgYXJlIG11dHVhbGx5IGV4Y2x1c2l2ZS4gQWJvcnRpbmcuIgoKIyAtLWN2ZWxpc3QtZmlsZSBtb2RlIGlzIHN0YW5kYWxvbmUgbW9kZSBhbmQgaXMgbm90IGFwcGxpY2FibGUgd2hlbiBvbmUgb2YgLWsgfCAtdSB8IC1wIHwgLS1jaGVja3NlYyBzd2l0Y2hlcyBhcmUgc2V0CmlmIFsgIiRvcHRfY3ZlbGlzdF9maWxlIiA9ICJ0cnVlIiBdOyB0aGVuCiAgICBbICEgLWUgIiRDVkVMSVNUX0ZJTEUiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlByb3ZpZGVkIENWRSBsaXN0IGZpbGUgZG9lcyBub3QgZXhpc3RzLiBBYm9ydGluZy4iCiAgICBbICIkb3B0X2tlcm5lbF92ZXJzaW9uIiA9ICJ0cnVlIiBdICYmIGV4aXRXaXRoRXJyTXNnICJTd2l0Y2hlcyAta3wtLWtlcm5lbCBhbmQgLS1jdmVsaXN0LWZpbGUgYXJlIG11dHVhbGx5IGV4Y2x1c2l2ZS4gQWJvcnRpbmcuIgogICAgWyAiJG9wdF91bmFtZV9zdHJpbmciID0gInRydWUiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlN3aXRjaGVzIC11fC0tdW5hbWUgYW5kIC0tY3ZlbGlzdC1maWxlIGFyZSBtdXR1YWxseSBleGNsdXNpdmUuIEFib3J0aW5nLiIKICAgIFsgIiRvcHRfcGtnbGlzdF9maWxlIiA9ICJ0cnVlIiBdICYmIGV4aXRXaXRoRXJyTXNnICJTd2l0Y2hlcyAtcHwtLXBrZ2xpc3QtZmlsZSBhbmQgLS1jdmVsaXN0LWZpbGUgYXJlIG11dHVhbGx5IGV4Y2x1c2l2ZS4gQWJvcnRpbmcuIgpmaQoKIyAtLWNoZWNrc2VjIG1vZGUgaXMgc3RhbmRhbG9uZSBtb2RlIGFuZCBpcyBub3QgYXBwbGljYWJsZSB3aGVuIG9uZSBvZiAtayB8IC11IHwgLXAgfCAtLWN2ZWxpc3QtZmlsZSBzd2l0Y2hlcyBhcmUgc2V0CmlmIFsgIiRvcHRfY2hlY2tzZWNfbW9kZSIgPSAidHJ1ZSIgXTsgdGhlbgogICAgWyAiJG9wdF9rZXJuZWxfdmVyc2lvbiIgPSAidHJ1ZSIgXSAmJiBleGl0V2l0aEVyck1zZyAiU3dpdGNoZXMgLWt8LS1rZXJuZWwgYW5kIC0tY2hlY2tzZWMgYXJlIG11dHVhbGx5IGV4Y2x1c2l2ZS4gQWJvcnRpbmcuIgogICAgWyAiJG9wdF91bmFtZV9zdHJpbmciID0gInRydWUiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlN3aXRjaGVzIC11fC0tdW5hbWUgYW5kIC0tY2hlY2tzZWMgYXJlIG11dHVhbGx5IGV4Y2x1c2l2ZS4gQWJvcnRpbmcuIgogICAgWyAiJG9wdF9wa2dsaXN0X2ZpbGUiID0gInRydWUiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlN3aXRjaGVzIC1wfC0tcGtnbGlzdC1maWxlIGFuZCAtLWNoZWNrc2VjIGFyZSBtdXR1YWxseSBleGNsdXNpdmUuIEFib3J0aW5nLiIKZmkKCiMgZXh0cmFjdCBrZXJuZWwgdmVyc2lvbiBhbmQgb3RoZXIgT1MgaW5mbyBsaWtlIGRpc3RybyBuYW1lLCBkaXN0cm8gdmVyc2lvbiwgZXRjLiAzIHBvc3NpYmlsaXRpZXMgaGVyZToKIyBjYXNlIDE6IC0ta2VybmVsIHNldAppZiBbICIkb3B0X2tlcm5lbF92ZXJzaW9uIiA9PSAidHJ1ZSIgXTsgdGhlbgogICAgIyBUT0RPOiBhZGQga2VybmVsIHZlcnNpb24gbnVtYmVyIHZhbGlkYXRpb24KICAgIFsgLXogIiRLRVJORUwiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIlVucmVjb2duaXplZCBrZXJuZWwgdmVyc2lvbiBnaXZlbi4gQWJvcnRpbmcuIgogICAgQVJDSD0iIgogICAgT1M9IiIKCiAgICAjIGRvIG5vdCBwZXJmb3JtIGFkZGl0aW9uYWwgY2hlY2tzIG9uIGN1cnJlbnQgbWFjaGluZQogICAgb3B0X3NraXBfbW9yZV9jaGVja3M9dHJ1ZQoKICAgICMgZG8gbm90IGNvbnNpZGVyIGN1cnJlbnQgT1MKICAgIGdldFBrZ0xpc3QgIiIgIiRQS0dMSVNUX0ZJTEUiCgojIGNhc2UgMjogLS11bmFtZSBzZXQKZWxpZiBbICIkb3B0X3VuYW1lX3N0cmluZyIgPT0gInRydWUiIF07IHRoZW4KICAgIFsgLXogIiRVTkFNRV9BIiBdICYmIGV4aXRXaXRoRXJyTXNnICJ1bmFtZSBzdHJpbmcgZW1wdHkuIEFib3J0aW5nLiIKICAgIHBhcnNlVW5hbWUgIiRVTkFNRV9BIgoKICAgICMgZG8gbm90IHBlcmZvcm0gYWRkaXRpb25hbCBjaGVja3Mgb24gY3VycmVudCBtYWNoaW5lCiAgICBvcHRfc2tpcF9tb3JlX2NoZWNrcz10cnVlCgogICAgIyBkbyBub3QgY29uc2lkZXIgY3VycmVudCBPUwogICAgZ2V0UGtnTGlzdCAiIiAiJFBLR0xJU1RfRklMRSIKCiMgY2FzZSAzOiAtLWN2ZWxpc3QtZmlsZSBtb2RlCmVsaWYgWyAiJG9wdF9jdmVsaXN0X2ZpbGUiID0gInRydWUiIF07IHRoZW4KCiAgICAjIGdldCBrZXJuZWwgY29uZmlndXJhdGlvbiBpbiB0aGlzIG1vZGUKICAgIFsgIiRvcHRfc2tpcF9tb3JlX2NoZWNrcyIgPSAiZmFsc2UiIF0gJiYgZ2V0S2VybmVsQ29uZmlnCgojIGNhc2UgNDogLS1jaGVja3NlYyBtb2RlCmVsaWYgWyAiJG9wdF9jaGVja3NlY19tb2RlIiA9ICJ0cnVlIiBdOyB0aGVuCgogICAgIyB0aGlzIHN3aXRjaCBpcyBub3QgYXBwbGljYWJsZSBpbiB0aGlzIG1vZGUKICAgIG9wdF9za2lwX21vcmVfY2hlY2tzPWZhbHNlCgogICAgIyBnZXQga2VybmVsIGNvbmZpZ3VyYXRpb24gaW4gdGhpcyBtb2RlCiAgICBnZXRLZXJuZWxDb25maWcKICAgIFsgLXogIiRLQ09ORklHIiBdICYmIGVjaG8gIldBUk5JTkcuIEtlcm5lbCBDb25maWcgbm90IGZvdW5kIG9uIHRoZSBzeXN0ZW0gcmVzdWx0cyB3b24ndCBiZSBjb21wbGV0ZS4iCgogICAgIyBsYXVuY2ggY2hlY2tzZWMgbW9kZQogICAgY2hlY2tzZWNNb2RlCgogICAgZXhpdCAwCgojIGNhc2UgNTogbm8gLS11bmFtZSB8IC0ta2VybmVsIHwgLS1jdmVsaXN0LWZpbGUgfCAtLWNoZWNrc2VjIHNldAplbHNlCgogICAgIyAtLXBrZ2xpc3QtZmlsZSBOT1QgcHJvdmlkZWQ6IHRha2UgYWxsIGluZm8gZnJvbSBjdXJyZW50IG1hY2hpbmUKICAgICMgY2FzZSBmb3IgdmFuaWxsYSBleGVjdXRpb246IC4vbGludXgtZXhwbG9pdC1zdWdnZXN0ZXIuc2gKICAgIGlmIFsgIiRvcHRfcGtnbGlzdF9maWxlIiA9PSAiZmFsc2UiIF07IHRoZW4KICAgICAgICBVTkFNRV9BPSQodW5hbWUgLWEpCiAgICAgICAgWyAteiAiJFVOQU1FX0EiIF0gJiYgZXhpdFdpdGhFcnJNc2cgInVuYW1lIHN0cmluZyBlbXB0eS4gQWJvcnRpbmcuIgogICAgICAgIHBhcnNlVW5hbWUgIiRVTkFNRV9BIgoKICAgICAgICAjIGdldCBrZXJuZWwgY29uZmlndXJhdGlvbiBpbiB0aGlzIG1vZGUKICAgICAgICBbICIkb3B0X3NraXBfbW9yZV9jaGVja3MiID0gImZhbHNlIiBdICYmIGdldEtlcm5lbENvbmZpZwoKICAgICAgICAjIGV4dHJhY3QgZGlzdHJpYnV0aW9uIHZlcnNpb24gZnJvbSAvZXRjL29zLXJlbGVhc2UgT1IgL2V0Yy9sc2ItcmVsZWFzZQogICAgICAgIFsgLW4gIiRPUyIgLWEgIiRvcHRfc2tpcF9tb3JlX2NoZWNrcyIgPSAiZmFsc2UiIF0gJiYgRElTVFJPPSQoZ3JlcCAtcyAtRSAnXkRJU1RSSUJfUkVMRUFTRT18XlZFUlNJT05fSUQ9JyAvZXRjLyotcmVsZWFzZSB8IGN1dCAtZCc9JyAtZjIgfCBoZWFkIC0xIHwgdHIgLWQgJyInKQoKICAgICAgICAjIGV4dHJhY3QgcGFja2FnZSBsaXN0aW5nIGZyb20gY3VycmVudCBPUwogICAgICAgIGdldFBrZ0xpc3QgIiRPUyIgIiIKCiAgICAjIC0tcGtnbGlzdC1maWxlIHByb3ZpZGVkOiBvbmx5IGNvbnNpZGVyIHVzZXJzcGFjZSBleHBsb2l0cyBhZ2FpbnN0IHByb3ZpZGVkIHBhY2thZ2UgbGlzdGluZwogICAgZWxzZQogICAgICAgIEtFUk5FTD0iIgogICAgICAgICNUT0RPOiBleHRyYWN0IG1hY2hpbmUgYXJjaCBmcm9tIHBhY2thZ2UgbGlzdGluZwogICAgICAgIEFSQ0g9IiIKICAgICAgICB1bnNldCBFWFBMT0lUUwogICAgICAgIGRlY2xhcmUgLUEgRVhQTE9JVFMKICAgICAgICBnZXRQa2dMaXN0ICIiICIkUEtHTElTVF9GSUxFIgoKICAgICAgICAjIGFkZGl0aW9uYWwgY2hlY2tzIGFyZSBub3QgYXBwbGljYWJsZSBmb3IgdGhpcyBtb2RlCiAgICAgICAgb3B0X3NraXBfbW9yZV9jaGVja3M9dHJ1ZQogICAgZmkKZmkKCmVjaG8KZWNobyAtZSAiJHtibGR3aHR9QXZhaWxhYmxlIGluZm9ybWF0aW9uOiR7dHh0cnN0fSIKZWNobwpbIC1uICIkS0VSTkVMIiBdICYmIGVjaG8gLWUgIktlcm5lbCB2ZXJzaW9uOiAke3R4dGdybn0kS0VSTkVMJHt0eHRyc3R9IiB8fCBlY2hvIC1lICJLZXJuZWwgdmVyc2lvbjogJHt0eHRyZWR9Ti9BJHt0eHRyc3R9IgplY2hvICJBcmNoaXRlY3R1cmU6ICQoWyAtbiAiJEFSQ0giIF0gJiYgZWNobyAtZSAiJHt0eHRncm59JEFSQ0gke3R4dHJzdH0iIHx8IGVjaG8gLWUgIiR7dHh0cmVkfU4vQSR7dHh0cnN0fSIpIgplY2hvICJEaXN0cmlidXRpb246ICQoWyAtbiAiJE9TIiBdICYmIGVjaG8gLWUgIiR7dHh0Z3JufSRPUyR7dHh0cnN0fSIgfHwgZWNobyAtZSAiJHt0eHRyZWR9Ti9BJHt0eHRyc3R9IikiCmVjaG8gLWUgIkRpc3RyaWJ1dGlvbiB2ZXJzaW9uOiAkKFsgLW4gIiRESVNUUk8iIF0gJiYgZWNobyAtZSAiJHt0eHRncm59JERJU1RSTyR7dHh0cnN0fSIgfHwgZWNobyAtZSAiJHt0eHRyZWR9Ti9BJHt0eHRyc3R9IikiCgplY2hvICJBZGRpdGlvbmFsIGNoZWNrcyAoQ09ORklHXyosIHN5c2N0bCBlbnRyaWVzLCBjdXN0b20gQmFzaCBjb21tYW5kcyk6ICQoWyAiJG9wdF9za2lwX21vcmVfY2hlY2tzIiA9PSAiZmFsc2UiIF0gJiYgZWNobyAtZSAiJHt0eHRncm59cGVyZm9ybWVkJHt0eHRyc3R9IiB8fCBlY2hvIC1lICIke3R4dHJlZH1OL0Eke3R4dHJzdH0iKSIKCmlmIFsgLW4gIiRQS0dMSVNUX0ZJTEUiIC1hIC1uICIkUEtHX0xJU1QiIF07IHRoZW4KICAgIHBrZ0xpc3RGaWxlPSIke3R4dGdybn0kUEtHTElTVF9GSUxFJHt0eHRyc3R9IgplbGlmIFsgLW4gIiRQS0dMSVNUX0ZJTEUiIF07IHRoZW4KICAgIHBrZ0xpc3RGaWxlPSIke3R4dHJlZH11bnJlY29nbml6ZWQgZmlsZSBwcm92aWRlZCR7dHh0cnN0fSIKZWxpZiBbIC1uICIkUEtHX0xJU1QiIF07IHRoZW4KICAgIHBrZ0xpc3RGaWxlPSIke3R4dGdybn1mcm9tIGN1cnJlbnQgT1Mke3R4dHJzdH0iCmZpCgplY2hvIC1lICJQYWNrYWdlIGxpc3Rpbmc6ICQoWyAtbiAiJHBrZ0xpc3RGaWxlIiBdICYmIGVjaG8gLWUgIiRwa2dMaXN0RmlsZSIgfHwgZWNobyAtZSAiJHt0eHRyZWR9Ti9BJHt0eHRyc3R9IikiCgojIGhhbmRsZSAtLWtlcm5lbHNwYWN5LW9ubHkgJiAtLXVzZXJzcGFjZS1vbmx5IGZpbHRlciBvcHRpb25zCmlmIFsgIiRvcHRfa2VybmVsX29ubHkiID0gInRydWUiIC1vIC16ICIkUEtHX0xJU1QiIF07IHRoZW4KICAgIHVuc2V0IEVYUExPSVRTX1VTRVJTUEFDRQogICAgZGVjbGFyZSAtQSBFWFBMT0lUU19VU0VSU1BBQ0UKZmkKCmlmIFsgIiRvcHRfdXNlcnNwYWNlX29ubHkiID0gInRydWUiIF07IHRoZW4KICAgIHVuc2V0IEVYUExPSVRTCiAgICBkZWNsYXJlIC1BIEVYUExPSVRTCmZpCgplY2hvCmVjaG8gLWUgIiR7Ymxkd2h0fVNlYXJjaGluZyBhbW9uZzoke3R4dHJzdH0iCmVjaG8KZWNobyAiJHsjRVhQTE9JVFNbQF19IGtlcm5lbCBzcGFjZSBleHBsb2l0cyIKZWNobyAiJHsjRVhQTE9JVFNfVVNFUlNQQUNFW0BdfSB1c2VyIHNwYWNlIGV4cGxvaXRzIgplY2hvCgplY2hvIC1lICIke2JsZHdodH1Qb3NzaWJsZSBFeHBsb2l0czoke3R4dHJzdH0iCmVjaG8KCiMgc3RhcnQgYW5hbHlzaXMKaj0wCmZvciBFWFAgaW4gIiR7RVhQTE9JVFNbQF19IiAiJHtFWFBMT0lUU19VU0VSU1BBQ0VbQF19IjsgZG8KCiAgICAjIGNyZWF0ZSBhcnJheSBmcm9tIGN1cnJlbnQgZXhwbG9pdCBoZXJlIGRvYyBhbmQgZmV0Y2ggbmVlZGVkIGxpbmVzCiAgICBpPTAKICAgICMgKCctcicgaXMgdXNlZCB0byBub3QgaW50ZXJwcmV0IGJhY2tzbGFzaCB1c2VkIGZvciBiYXNoIGNvbG9ycykKICAgIHdoaWxlIHJlYWQgLXIgbGluZQogICAgZG8KICAgICAgICBhcnJbaV09IiRsaW5lIgogICAgICAgIGk9JCgoaSArIDEpKQogICAgZG9uZSA8PDwgIiRFWFAiCgogICAgTkFNRT0iJHthcnJbMF19IiAmJiBOQU1FPSIke05BTUU6Nn0iCiAgICBSRVFTPSIke2FyclsxXX0iICYmIFJFUVM9IiR7UkVRUzo2fSIKICAgIFRBR1M9IiR7YXJyWzJdfSIgJiYgVEFHUz0iJHtUQUdTOjZ9IgogICAgUkFOSz0iJHthcnJbM119IiAmJiBSQU5LPSIke1JBTks6Nn0iCgogICAgIyBzcGxpdCBsaW5lIHdpdGggcmVxdWlyZW1lbnRzICYgbG9vcCB0aHJ1IGFsbCByZXFzIG9uZSBieSBvbmUgJiBjaGVjayB3aGV0aGVyIGl0IGlzIG1ldAogICAgSUZTPScsJyByZWFkIC1yIC1hIGFycmF5IDw8PCAiJFJFUVMiCiAgICBSRVFTX05VTT0keyNhcnJheVtAXX0KICAgIFBBU1NFRF9SRVE9MAogICAgZm9yIFJFUSBpbiAiJHthcnJheVtAXX0iOyBkbwogICAgICAgIGlmIChjaGVja1JlcXVpcmVtZW50ICIkUkVRIiAiJHthcnJheVswXX0iKTsgdGhlbgogICAgICAgICAgICBQQVNTRURfUkVRPSQoKCRQQVNTRURfUkVRICsgMSkpCiAgICAgICAgZWxzZQogICAgICAgICAgICBicmVhawogICAgICAgIGZpCiAgICBkb25lCgogICAgIyBleGVjdXRlIGZvciBleHBsb2l0cyB3aXRoIGFsbCByZXF1aXJlbWVudHMgbWV0CiAgICBpZiBbICRQQVNTRURfUkVRIC1lcSAkUkVRU19OVU0gXTsgdGhlbgoKICAgICAgICAjIGFkZGl0aW9uYWwgcmVxdWlyZW1lbnQgZm9yIC0tY3ZlbGlzdC1maWxlIG1vZGU6IGNoZWNrIGlmIENWRSBhc3NvY2lhdGVkIHdpdGggdGhlIGV4cGxvaXQgaXMgb24gdGhlIENWRUxJU1RfRklMRQogICAgICAgIGlmIFsgIiRvcHRfY3ZlbGlzdF9maWxlIiA9ICJ0cnVlIiBdOyB0aGVuCgogICAgICAgICAgICAjIGV4dHJhY3QgQ1ZFKHMpIGFzc29jaWF0ZWQgd2l0aCBnaXZlbiBleHBsb2l0IChhbHNvIHRyYW5zbGF0ZXMgJywnIHRvICd8JyBmb3IgZWFzeSBoYW5kbGluZyBtdWx0aXBsZSBDVkVzIGNhc2UgLSB2aWEgZXh0ZW5kZWQgcmVnZXgpCiAgICAgICAgICAgIGN2ZT0kKGVjaG8gIiROQU1FIiB8IGdyZXAgJy4qXFsuKlxdLionIHwgY3V0IC1kICdtJyAtZjIgfCBjdXQgLWQgJ10nIC1mMSB8IHRyIC1kICdbJyB8IHRyICIsIiAifCIpCiAgICAgICAgICAgICNlY2hvICJDVkU6ICRjdmUiCgogICAgICAgICAgICAjIGNoZWNrIGlmIGl0J3Mgb24gQ1ZFTElTVF9GSUxFIGxpc3QsIGlmIG5vIG1vdmUgdG8gbmV4dCBleHBsb2l0CiAgICAgICAgICAgIFsgISAkKGNhdCAiJENWRUxJU1RfRklMRSIgfCBncmVwIC1FICIkY3ZlIikgXSAmJiBjb250aW51ZQogICAgICAgIGZpCgogICAgICAgICMgcHJvY2VzcyB0YWdzIGFuZCBoaWdobGlnaHQgdGhvc2UgdGhhdCBtYXRjaCBjdXJyZW50IE9TIChvbmx5IGZvciBkZWJ8dWJ1bnR1fFJIRUwgYW5kIGlmIHdlIGtub3cgZGlzdHJvIHZlcnNpb24gLSBkaXJlY3QgbW9kZSkKICAgICAgICB0YWdzPSIiCiAgICAgICAgaWYgWyAtbiAiJFRBR1MiIC1hIC1uICIkT1MiIF07IHRoZW4KICAgICAgICAgICAgSUZTPScsJyByZWFkIC1yIC1hIHRhZ3NfYXJyYXkgPDw8ICIkVEFHUyIKICAgICAgICAgICAgVEFHU19OVU09JHsjdGFnc19hcnJheVtAXX0KCiAgICAgICAgICAgICMgYnVtcCBSQU5LIHNsaWdodGx5ICgrMSkgaWYgd2UncmUgaW4gJy0tdW5hbWUnIG1vZGUgYW5kIHRoZXJlJ3MgYSBUQUcgZm9yIE9TIGZyb20gdW5hbWUgc3RyaW5nCiAgICAgICAgICAgIFsgIiQoZWNobyAiJHt0YWdzX2FycmF5W0BdfSIgfCBncmVwICIkT1MiKSIgLWEgIiRvcHRfdW5hbWVfc3RyaW5nIiA9PSAidHJ1ZSIgXSAmJiBSQU5LPSQoKCRSQU5LICsgMSkpCgogICAgICAgICAgICBmb3IgVEFHIGluICIke3RhZ3NfYXJyYXlbQF19IjsgZG8KICAgICAgICAgICAgICAgIHRhZ19kaXN0cm89JChlY2hvICIkVEFHIiB8IGN1dCAtZCc9JyAtZjEpCiAgICAgICAgICAgICAgICB0YWdfZGlzdHJvX251bV9hbGw9JChlY2hvICIkVEFHIiB8IGN1dCAtZCc9JyAtZjIpCiAgICAgICAgICAgICAgICAjIGluIGNhc2Ugb2YgdGFnIG9mIGZvcm06ICd1YnVudHU9MTYuMDR7a2VybmVsOjQuNC4wLTIxfSByZW1vdmUga2VybmVsIHZlcnNpb25pbmcgcGFydCBmb3IgY29tcGFyaXNpb24KICAgICAgICAgICAgICAgIHRhZ19kaXN0cm9fbnVtPSIke3RhZ19kaXN0cm9fbnVtX2FsbCV7Kn0iCgogICAgICAgICAgICAgICAgIyB3ZSdyZSBpbiAnLS11bmFtZScgbW9kZSBPUiAoZm9yIG5vcm1hbCBtb2RlKSBpZiB0aGVyZSBpcyBkaXN0cm8gdmVyc2lvbiBtYXRjaAogICAgICAgICAgICAgICAgaWYgWyAiJG9wdF91bmFtZV9zdHJpbmciID09ICJ0cnVlIiAtbyBcKCAiJE9TIiA9PSAiJHRhZ19kaXN0cm8iIC1hICIkKGVjaG8gIiRESVNUUk8iIHwgZ3JlcCAtRSAiJHRhZ19kaXN0cm9fbnVtIikiIFwpIF07IHRoZW4KCiAgICAgICAgICAgICAgICAgICAgIyBidW1wIGN1cnJlbnQgZXhwbG9pdCdzIHJhbmsgYnkgMiBmb3IgZGlzdHJvIG1hdGNoIChhbmQgbm90IGluICctLXVuYW1lJyBtb2RlKQogICAgICAgICAgICAgICAgICAgIFsgIiRvcHRfdW5hbWVfc3RyaW5nIiA9PSAiZmFsc2UiIF0gJiYgUkFOSz0kKCgkUkFOSyArIDIpKQoKICAgICAgICAgICAgICAgICAgICAjIGdldCBuYW1lIChrZXJuZWwgb3IgcGFja2FnZSBuYW1lKSBhbmQgdmVyc2lvbiBvZiBrZXJuZWwvcGtnIGlmIHByb3ZpZGVkOgogICAgICAgICAgICAgICAgICAgIHRhZ19wa2c9JChlY2hvICIkdGFnX2Rpc3Ryb19udW1fYWxsIiB8IGN1dCAtZCd7JyAtZiAyIHwgdHIgLWQgJ30nIHwgY3V0IC1kJzonIC1mIDEpCiAgICAgICAgICAgICAgICAgICAgdGFnX3BrZ19udW09IiIKICAgICAgICAgICAgICAgICAgICBbICQoZWNobyAiJHRhZ19kaXN0cm9fbnVtX2FsbCIgfCBncmVwICd7JykgXSAmJiB0YWdfcGtnX251bT0kKGVjaG8gIiR0YWdfZGlzdHJvX251bV9hbGwiIHwgY3V0IC1kJ3snIC1mIDIgfCB0ciAtZCAnfScgfCBjdXQgLWQnOicgLWYgMikKCiAgICAgICAgICAgICAgICAgICAgI1sgLW4gIiR0YWdfcGtnX251bSIgXSAmJiBlY2hvICJ0YWdfcGtnX251bTogJHRhZ19wa2dfbnVtOyBrZXJuZWw6ICRLRVJORUxfQUxMIgoKICAgICAgICAgICAgICAgICAgICAjIGlmIHBrZy9rZXJuZWwgdmVyc2lvbiBpcyBub3QgcHJvdmlkZWQ6CiAgICAgICAgICAgICAgICAgICAgaWYgWyAteiAiJHRhZ19wa2dfbnVtIiBdOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgICAgIFsgIiRvcHRfdW5hbWVfc3RyaW5nIiA9PSAiZmFsc2UiIF0gJiYgVEFHPSIke2xpZ2h0eWVsbG93fVsgJHtUQUd9IF0ke3R4dHJzdH0iCgogICAgICAgICAgICAgICAgICAgICMga2VybmVsIHZlcnNpb24gcHJvdmlkZWQsIGNoZWNrIGZvciBtYXRjaDoKICAgICAgICAgICAgICAgICAgICBlbGlmIFsgLW4gIiR0YWdfcGtnX251bSIgLWEgIiR0YWdfcGtnIiA9ICJrZXJuZWwiIF07IHRoZW4KICAgICAgICAgICAgICAgICAgICAgICAgaWYgWyAkKGVjaG8gIiRLRVJORUxfQUxMIiB8IGdyZXAgLUUgIiR7dGFnX3BrZ19udW19IikgXTsgdGhlbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgIyBrZXJuZWwgdmVyc2lvbiBtYXRjaGVkIC0gYm9sZCBoaWdobGlnaHQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFRBRz0iJHt5ZWxsb3d9WyAke1RBR30gXSR7dHh0cnN0fSIKCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAjIGJ1bXAgY3VycmVudCBleHBsb2l0J3MgcmFuayBhZGRpdGlvbmFsbHkgYnkgMyBmb3Iga2VybmVsIHZlcnNpb24gcmVnZXggbWF0Y2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJBTks9JCgoJFJBTksgKyAzKSkKICAgICAgICAgICAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgWyAiJG9wdF91bmFtZV9zdHJpbmciID09ICJmYWxzZSIgXSAmJiBUQUc9IiR7bGlnaHR5ZWxsb3d9WyAkdGFnX2Rpc3Rybz0kdGFnX2Rpc3Ryb19udW0gXSR7dHh0cnN0fXtrZXJuZWw6JHRhZ19wa2dfbnVtfSIKICAgICAgICAgICAgICAgICAgICAgICAgZmkKCiAgICAgICAgICAgICAgICAgICAgIyBwa2cgdmVyc2lvbiBwcm92aWRlZCwgY2hlY2sgZm9yIG1hdGNoIChUQkQpOgogICAgICAgICAgICAgICAgICAgIGVsaWYgWyAtbiAiJHRhZ19wa2dfbnVtIiAtYSAtbiAiJHRhZ19wa2ciICBdOyB0aGVuCiAgICAgICAgICAgICAgICAgICAgICAgIFRBRz0iJHtsaWdodHllbGxvd31bICR0YWdfZGlzdHJvPSR0YWdfZGlzdHJvX251bSBdJHt0eHRyc3R9eyR0YWdfcGtnOiR0YWdfcGtnX251bX0iCiAgICAgICAgICAgICAgICAgICAgZmkKCiAgICAgICAgICAgICAgICBmaQoKICAgICAgICAgICAgICAgICMgYXBwZW5kIGN1cnJlbnQgdGFnIHRvIHRhZ3MgbGlzdAogICAgICAgICAgICAgICAgdGFncz0iJHt0YWdzfSR7VEFHfSwiCiAgICAgICAgICAgIGRvbmUKICAgICAgICAgICAgIyB0cmltICcsJyBhZGRlZCBieSBhYm92ZSBsb29wCiAgICAgICAgICAgIFsgLW4gIiR0YWdzIiBdICYmIHRhZ3M9IiR7dGFncyU/fSIKICAgICAgICBlbHNlCiAgICAgICAgICAgIHRhZ3M9IiRUQUdTIgogICAgICAgIGZpCgogICAgICAgICMgaW5zZXJ0IHRoZSBtYXRjaGVkIGV4cGxvaXQgKHdpdGggY2FsY3VsYXRlZCBSYW5rIGFuZCBoaWdobGlnaHRlZCB0YWdzKSB0byBhcnJhcnkgdGhhdCB3aWxsIGJlIHNvcnRlZAogICAgICAgIEVYUD0kKGVjaG8gIiRFWFAiIHwgc2VkIC1lICcvXk5hbWU6L2QnIC1lICcvXlJlcXM6L2QnIC1lICcvXlRhZ3M6L2QnKQogICAgICAgIGV4cGxvaXRzX3RvX3NvcnRbal09IiR7UkFOS31OYW1lOiAke05BTUV9RDNMMW1SZXFzOiAke1JFUVN9RDNMMW1UYWdzOiAke3RhZ3N9RDNMMW0kKGVjaG8gIiRFWFAiIHwgc2VkIC1lICc6YScgLWUgJ04nIC1lICckIWJhJyAtZSAncy9cbi9EM0wxbS9nJykiCiAgICAgICAgKChqKyspKQogICAgZmkKZG9uZQoKIyBzb3J0IGV4cGxvaXRzIGJhc2VkIG9uIGNhbGN1bGF0ZWQgUmFuawpJRlM9JCdcbicKU09SVEVEX0VYUExPSVRTPSgkKHNvcnQgLXIgPDw8IiR7ZXhwbG9pdHNfdG9fc29ydFsqXX0iKSkKdW5zZXQgSUZTCgojIGRpc3BsYXkgc29ydGVkIGV4cGxvaXRzCmZvciBFWFBfVEVNUCBpbiAiJHtTT1JURURfRVhQTE9JVFNbQF19IjsgZG8KCglSQU5LPSQoZWNobyAiJEVYUF9URU1QIiB8IGF3ayAtRidOYW1lOicgJ3twcmludCAkMX0nKQoKCSMgY29udmVydCBlbnRyeSBiYWNrIHRvIGNhbm9uaWNhbCBmb3JtCglFWFA9JChlY2hvICIkRVhQX1RFTVAiIHwgc2VkICdzL15bMC05XS8vZycgfCBzZWQgJ3MvRDNMMW0vXG4vZycpCgoJIyBjcmVhdGUgYXJyYXkgZnJvbSBjdXJyZW50IGV4cGxvaXQgaGVyZSBkb2MgYW5kIGZldGNoIG5lZWRlZCBsaW5lcwogICAgaT0wCiAgICAjICgnLXInIGlzIHVzZWQgdG8gbm90IGludGVycHJldCBiYWNrc2xhc2ggdXNlZCBmb3IgYmFzaCBjb2xvcnMpCiAgICB3aGlsZSByZWFkIC1yIGxpbmUKICAgIGRvCiAgICAgICAgYXJyW2ldPSIkbGluZSIKICAgICAgICBpPSQoKGkgKyAxKSkKICAgIGRvbmUgPDw8ICIkRVhQIgoKICAgIE5BTUU9IiR7YXJyWzBdfSIgJiYgTkFNRT0iJHtOQU1FOjZ9IgogICAgUkVRUz0iJHthcnJbMV19IiAmJiBSRVFTPSIke1JFUVM6Nn0iCiAgICBUQUdTPSIke2FyclsyXX0iICYmIHRhZ3M9IiR7VEFHUzo2fSIKCglFWFBMT0lUX0RCPSQoZWNobyAiJEVYUCIgfCBncmVwICJleHBsb2l0LWRiOiAiIHwgYXdrICd7cHJpbnQgJDJ9JykKCWFuYWx5c2lzX3VybD0kKGVjaG8gIiRFWFAiIHwgZ3JlcCAiYW5hbHlzaXMtdXJsOiAiIHwgYXdrICd7cHJpbnQgJDJ9JykKCWV4dF91cmw9JChlY2hvICIkRVhQIiB8IGdyZXAgImV4dC11cmw6ICIgfCBhd2sgJ3twcmludCAkMn0nKQoJY29tbWVudHM9JChlY2hvICIkRVhQIiB8IGdyZXAgIkNvbW1lbnRzOiAiIHwgY3V0IC1kJyAnIC1mIDItKQoJcmVxcz0kKGVjaG8gIiRFWFAiIHwgZ3JlcCAiUmVxczogIiB8IGN1dCAtZCcgJyAtZiAyKQoKCSMgZXhwbG9pdCBuYW1lIHdpdGhvdXQgQ1ZFIG51bWJlciBhbmQgd2l0aG91dCBjb21tb25seSB1c2VkIHNwZWNpYWwgY2hhcnMKCW5hbWU9JChlY2hvICIkTkFNRSIgfCBjdXQgLWQnICcgLWYgMi0gfCB0ciAtZCAnICgpLycpCgoJYmluX3VybD0kKGVjaG8gIiRFWFAiIHwgZ3JlcCAiYmluLXVybDogIiB8IGF3ayAne3ByaW50ICQyfScpCglzcmNfdXJsPSQoZWNobyAiJEVYUCIgfCBncmVwICJzcmMtdXJsOiAiIHwgYXdrICd7cHJpbnQgJDJ9JykKCVsgLXogIiRzcmNfdXJsIiBdICYmIFsgLW4gIiRFWFBMT0lUX0RCIiBdICYmIHNyY191cmw9Imh0dHBzOi8vd3d3LmV4cGxvaXQtZGIuY29tL2Rvd25sb2FkLyRFWFBMT0lUX0RCIgoJWyAteiAiJHNyY191cmwiIF0gJiYgWyAteiAiJGJpbl91cmwiIF0gJiYgZXhpdFdpdGhFcnJNc2cgIidzcmMtdXJsJyAvICdiaW4tdXJsJyAvICdleHBsb2l0LWRiJyBlbnRyaWVzIGFyZSBhbGwgZW1wdHkgZm9yICckTkFNRScgZXhwbG9pdCAtIGZpeCB0aGF0LiBBYm9ydGluZy4iCgoJaWYgWyAtbiAiJGFuYWx5c2lzX3VybCIgXTsgdGhlbgogICAgICAgIGRldGFpbHM9IiRhbmFseXNpc191cmwiCgllbGlmICQoZWNobyAiJHNyY191cmwiIHwgZ3JlcCAtcSAnd3d3LmV4cGxvaXQtZGIuY29tJyk7IHRoZW4KICAgICAgICBkZXRhaWxzPSJodHRwczovL3d3dy5leHBsb2l0LWRiLmNvbS9leHBsb2l0cy8kRVhQTE9JVF9EQi8iCgllbGlmIFtbICIkc3JjX3VybCIgPX4gXi4qdGd6fHRhci5nenx6aXAkICYmIC1uICIkRVhQTE9JVF9EQiIgXV07IHRoZW4KICAgICAgICBkZXRhaWxzPSJodHRwczovL3d3dy5leHBsb2l0LWRiLmNvbS9leHBsb2l0cy8kRVhQTE9JVF9EQi8iCgllbHNlCiAgICAgICAgZGV0YWlscz0iJHNyY191cmwiCglmaQoKCSMgc2tpcCBEb1MgYnkgZGVmYXVsdAoJZG9zPSQoZWNobyAiJEVYUCIgfCBncmVwIC1vIC1pICIoZG9zIikKCVsgIiRvcHRfc2hvd19kb3MiID09ICJmYWxzZSIgXSAmJiBbIC1uICIkZG9zIiBdICYmIGNvbnRpbnVlCgoJIyBoYW5kbGVzIC0tZmV0Y2gtYmluYXJpZXMgb3B0aW9uCglpZiBbICRvcHRfZmV0Y2hfYmlucyA9ICJ0cnVlIiBdOyB0aGVuCiAgICAgICAgZm9yIGkgaW4gJChlY2hvICIkRVhQIiB8IGdyZXAgImJpbi11cmw6ICIgfCBhd2sgJ3twcmludCAkMn0nKTsgZG8KICAgICAgICAgICAgWyAtZiAiJHtuYW1lfV8kKGJhc2VuYW1lICRpKSIgXSAmJiBybSAtZiAiJHtuYW1lfV8kKGJhc2VuYW1lICRpKSIKICAgICAgICAgICAgd2dldCAtcSAtayAiJGkiIC1PICIke25hbWV9XyQoYmFzZW5hbWUgJGkpIgogICAgICAgIGRvbmUKICAgIGZpCgoJIyBoYW5kbGVzIC0tZmV0Y2gtc291cmNlcyBvcHRpb24KCWlmIFsgJG9wdF9mZXRjaF9zcmNzID0gInRydWUiIF07IHRoZW4KICAgICAgICBbIC1mICIke25hbWV9XyQoYmFzZW5hbWUgJHNyY191cmwpIiBdICYmIHJtIC1mICIke25hbWV9XyQoYmFzZW5hbWUgJHNyY191cmwpIgogICAgICAgIHdnZXQgLXEgLWsgIiRzcmNfdXJsIiAtTyAiJHtuYW1lfV8kKGJhc2VuYW1lICRzcmNfdXJsKSIgJgogICAgZmkKCiAgICAjIGRpc3BsYXkgcmVzdWx0IChzaG9ydCkKCWlmIFsgIiRvcHRfc3VtbWFyeSIgPSAidHJ1ZSIgXTsgdGhlbgoJWyAteiAiJHRhZ3MiIF0gJiYgdGFncz0iLSIKCWVjaG8gLWUgIiROQU1FIHx8ICR0YWdzIHx8ICRzcmNfdXJsIgoJY29udGludWUKCWZpCgojIGRpc3BsYXkgcmVzdWx0IChzdGFuZGFyZCkKCWVjaG8gLWUgIlsrXSAkTkFNRSIKCWVjaG8gLWUgIlxuICAgRGV0YWlsczogJGRldGFpbHMiCiAgICAgICAgZWNobyAtZSAiICAgRXhwb3N1cmU6ICQoZGlzcGxheUV4cG9zdXJlICRSQU5LKSIKICAgICAgICBbIC1uICIkdGFncyIgXSAmJiBlY2hvIC1lICIgICBUYWdzOiAkdGFncyIKICAgICAgICBlY2hvIC1lICIgICBEb3dubG9hZCBVUkw6ICRzcmNfdXJsIgogICAgICAgIFsgLW4gIiRleHRfdXJsIiBdICYmIGVjaG8gLWUgIiAgIGV4dC11cmw6ICRleHRfdXJsIgogICAgICAgIFsgLW4gIiRjb21tZW50cyIgXSAmJiBlY2hvIC1lICIgICBDb21tZW50czogJGNvbW1lbnRzIgoKICAgICAgICAjIGhhbmRsZXMgLS1mdWxsIGZpbHRlciBvcHRpb24KICAgICAgICBpZiBbICIkb3B0X2Z1bGwiID0gInRydWUiIF07IHRoZW4KICAgICAgICAgICAgWyAtbiAiJHJlcXMiIF0gJiYgZWNobyAtZSAiICAgUmVxdWlyZW1lbnRzOiAkcmVxcyIKCiAgICAgICAgICAgIFsgLW4gIiRFWFBMT0lUX0RCIiBdICYmIGVjaG8gLWUgIiAgIGV4cGxvaXQtZGI6ICRFWFBMT0lUX0RCIgoKICAgICAgICAgICAgYXV0aG9yPSQoZWNobyAiJEVYUCIgfCBncmVwICJhdXRob3I6ICIgfCBjdXQgLWQnICcgLWYgMi0pCiAgICAgICAgICAgIFsgLW4gIiRhdXRob3IiIF0gJiYgZWNobyAtZSAiICAgYXV0aG9yOiAkYXV0aG9yIgogICAgICAgIGZpCgogICAgICAgIGVjaG8KCmRvbmUK"
        echo $les_b64 | base64 -d | bash | sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" | grep -i "\[CVE" -A 10 | grep -Ev "^\-\-$" | sed -${E} "s/\[(CVE-[0-9]+-[0-9]+,?)+\].*/${SED_RED}/g"
        
        echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    fi
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

    current_user=$(whoami)
    uid=$(id -u)
    gid=$(id -g)
    primary_group=$(id -gn)

    echo -e "\e[1;33mCurrent User:\e[0m $current_user"
    echo -e "\e[1;33mUser ID (UID):\e[0m $uid"
    echo -e "\e[1;33mGroup ID (GID):\e[0m $gid"
    echo -e "\e[1;33mPrimary Group:\e[0m $primary_group"

    # Properly format group memberships
    echo -e "\e[1;33mGroup Memberships:\e[0m"
    group_memberships=$(id -Gn | tr ' ' '\n' | while read group; do
        highlight_groups "$group"
    done)
    echo -e "$group_memberships"

    # Store formatted data for summary
    user_info_summary="User: $current_user (UID: $uid, GID: $gid)\nPrimary Group: $primary_group\nGroups: $(id -Gn | tr ' ' ', ')"

    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display logged in users and last login information
logged_users_info() {
    echo -e "\n\n\e[1;34m[+] Gathering Logged In Users and Last Login Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    echo -e "\e[1;33mLast Login Information:\e[0m"
    if command -v lastlog >/dev/null; then
        lastlog | grep -v "Never logged in" | awk '{print $1 " - " $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9}'
    else
        echo -e "\e[1;31mCommand lastlog not available, cannot check last login information\e[0m"
    fi

    # Add some spacing
    echo -e "\n"

    echo -e "\e[1;33mCurrently Logged In Users:\e[0m"
    if command -v w >/dev/null; then
        w
    else
        echo -e "\e[1;31mCommand w not available, cannot check currently logged in users\e[0m"
    fi
    # Store formatted data for summary
    if command -v lastlog >/dev/null && command -v w >/dev/null; then
        logged_users_summary="Last Logins: $(lastlog | grep -v "Never logged in" | wc -l) users; Current Users: $(w -h | wc -l)"
    else
        logged_users_summary="Commands not available"
    fi
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
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

# Function to display user's PATH and highlight non-normal entries
path_info() {
    echo -e "\n\n\e[1;34m[+] Gathering PATH Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    current_path="$PATH"
    echo -e "\e[1;33mCurrent PATH:\e[0m $current_path"
    echo -e "\e[1;33mPATH Entries:\e[0m"
    IFS=':' read -r -a path_array <<< "$PATH"
    for dir in "${path_array[@]}"; do
        if [ -z "$dir" ]; then
            echo -e "\e[1;31m(Empty entry - non-normal)\e[0m"
        elif [ "$dir" = "." ]; then
            echo -e "\e[1;31m$dir (Current directory - non-normal)\e[0m"
        elif [ -d "$dir" ] && [ -w "$dir" ]; then
            echo -e "\e[1;31m$dir (Writable - non-normal)\e[0m"
        else
            echo "$dir"
        fi
    done
    # Store formatted data for summary
    path_info_summary="PATH: $current_path\nNon-normal entries: $(IFS=':'; for dir in "${path_array[@]}"; do if [ -z "$dir" ] || [ "$dir" = "." ] || ([ -d "$dir" ] && [ -w "$dir" ]); then echo -n "$dir, "; fi; done | sed 's/, $//')"
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display shell history and history files
history_info() {
    echo -e "\n\n\e[1;34m[+] Gathering Shell History Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    echo -e "\e[1;33mCurrent Shell History:\e[0m"
    if [ -f ~/.bash_history ]; then
        cat ~/.bash_history
    else
        history
    fi
    # Add some spacing
    echo -e "\n"
    echo -e "\e[1;33mHistory Files Found:\e[0m"
    find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /nix -o -path /snap \) -prune -o -type f \( -name "*_history*" \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
        if [ -r "$file" ]; then
            echo -e "\e[1;31m$file (Readable):\e[0m"
            cat "$file"
            # Add some spacing
            echo -e "\n"
        else
            echo "$file (Not readable)"
            # Add some spacing
            echo -e "\n"
        fi
    done
    # Store formatted data for summary
    history_summary="Current history entries: $(history | wc -l); Found files: $(find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /nix -o -path /snap \) -prune -o -type f \( -name "*_history*" \) 2>/dev/null | wc -l)"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display /etc/hosts contents
hosts_file() {
    echo -e "\n\n\e[1;34m[+] Gathering /etc/hosts Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    if [ -r /etc/hosts ]; then
        echo -e "\e[1;33m/etc/hosts Contents:\e[0m"
        cat /etc/hosts | grep -v '^#' | grep -v '^$' | while read line; do
            if echo "$line" | grep -qE '^(127\.|::1)'; then
                echo "$line"
            else
                echo -e "\e[1;31m$line (Non-local entry)\e[0m"
            fi
        done
    else
        echo -e "\e[1;31m/etc/hosts not readable\e[0m"
    fi
   
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display network interfaces and IP addresses
network_interfaces() {
    echo -e "\n\n\e[1;34m[+] Gathering Network Interfaces and IP Addresses\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    if command -v ip >/dev/null 2>&1; then
        ip -brief addr show | while read -r iface state addr _; do
            if [[ "$addr" != "" ]]; then
                echo -e "\e[1;33m[!] Interface:\e[0m $iface -> $addr"
            else
                echo -e "\e[1;33m[!] Interface:\e[0m $iface -> No IP assigned"
            fi
        done
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig | awk '/^[a-z]/ { iface=$1 } /inet / { print iface, $2 }' | while read -r iface ip; do
            echo -e "\e[1;33m[!] Interface:\e[0m $iface -> $ip"
        done
    else
        echo -e "\e[1;31m[-] No network interface tools found (ip/ifconfig).\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display listening ports and associated processes
listening_ports() {
    echo -e "\n\n\e[1;34m[+] Checking Listening Ports and Associated Processes\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    if command -v ss >/dev/null 2>&1; then
        ss -tulnp | tail -n +2 | awk '{split($5, addr, ":"); port=addr[length(addr)]; proc=($7=="") ? "(Unknown: Insufficient Privileges)" : $7; print port, proc}' | while read -r port proc; do
            echo -e "\e[1;33m[!] Port:\e[0m $port -> $proc"
        done
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulnp | tail -n +3 | awk '{split($4, addr, ":"); port=addr[length(addr)]; proc=($7=="") ? "(Unknown: Insufficient Privileges)" : $7; print port, proc}' | while read -r port proc; do
            echo -e "\e[1;33m[!] Port:\e[0m $port -> $proc"
        done
    else
        echo -e "\e[1;31m[-] No network tools found (ss/netstat).\e[0m"
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display routing table
routing_table() {
    echo -e "\n\n\e[1;34m[+] Gathering Routing Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    echo -e "\e[1;33mRouting Table:\e[0m"
    if command -v ip >/dev/null; then
        ip route show
    elif command -v route >/dev/null; then
        route -n
    else
        echo -e "\e[1;31mNo routing command available\e[0m"
    fi
    # Store formatted data for summary
    routing_summary=$(if command -v ip >/dev/null; then ip route show; elif command -v route >/dev/null; then route -n; else echo "No routing info"; fi | tr '\n' '; ')
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
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
                cat "/etc/cron.d/$cron_file" | sed 's/^/        /'

                # Check if cron_file is writable
                if [ -w "/etc/cron.d/$cron_file" ]; then
                    echo -e "\e[1;31m[!] /etc/cron.d/$cron_file is writable! Potential security risk.\e[0m"
                    cron_summary="/etc/cron.d/$cron_file is writable! Review required."
                else
                    echo -e "    \e[1;32m/etc/crontab is not writable.\e[0m"
                fi
                    done
                fi
    else
        echo -e "    \e[1;31m/etc/cron.d directory not found.\e[0m"
    fi
    if [ -d /etc/cron.daily ]; then
        cron_files=$(ls /etc/cron.daily 2>/dev/null)
        if [ -z "$cron_files" ]; then
            echo -e "    \e[1;31mNo cron jobs found in /etc/cron.daily\e[0m"
        else
            for cron_file in $cron_files; do
                echo -e "    /etc/cron.daily/$cron_file"
                cat "/etc/cron.daily/$cron_file" | sed 's/^/        /'

                # Check if cron_file is writable
                if [ -w "/etc/cron.daily/$cron_file" ]; then
                    echo -e "\e[1;31m[!] /etc/cron.daily/$cron_file is writable! Potential security risk.\e[0m"
                    cron_summary="/etc/cron.daily/$cron_file is writable! Review required."
                else
                    echo -e "    \e[1;32m/etc/cron.daily/$cron_file is not writable.\e[0m"
                fi
            done
        fi
    else
        echo -e "    \e[1;31m/etc/cron.daily directory not found.\e[0m"
    fi
    if [ -d /var/spool/cron/crontabs ]; then
        cron_files=$(ls /var/spool/cron/crontabs 2>/dev/null)
        if [ -z "$cron_files" ]; then
            echo -e "    \e[1;31mNo cron jobs found in /var/spool/cron/crontabs\e[0m"
        else
            for cron_file in $cron_files; do
                echo -e "    /var/spool/cron/crontabs/$cron_file"
                cat "/var/spool/cron/crontabs/$cron_file" | sed 's/^/        /'

                # Check if cron_file is writable
                if [ -w "/var/spool/cron/crontabs/$cron_file" ]; then
                    echo -e "\e[1;31m[!] /var/spool/cron/crontabs/$cron_file is writable! Potential security risk.\e[0m"
                    cron_summary="/etc/cron.daily/$cron_file is writable! Review required."
                else
                    echo -e "    \e[1;32m/etc/cron.daily/$cron_file is not writable.\e[0m"
                fi
            done
        fi
    else
        echo -e "    \e[1;31m/var/spool/cron/crontabs directory not found.\e[0m"
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
    writable_cron_files=$(find /etc/cron* /var/spool/cron/ -type f -writable 2>/dev/null)
    if [ -z "$writable_cron_files" ]; then
        echo -e " \e[1;31mNo writable cron files found.\e[0m"
    else
        echo -e "\e[1;31m[!] Writable cron files detected! Potential security risk:\e[0m"
        echo "$writable_cron_files" | sed 's/^/ /'
        cron_summary="Writable cron files detected! Review required."
    fi

    # Give user a hint to also check for cronjobs with pspy
    echo -e "\n\e[1;31m[!] Remember to also check for non-visible cronjobs using pspy!\e[0m"

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



# Function to display mounted filesystems
filesystems_info() {
    echo -e "\n\n\e[1;34m[+] Gathering Filesystem Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    if command -v lsblk >/dev/null; then
        echo -e "\e[1;33mBlock Devices:\e[0m"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    fi
    if command -v findmnt >/dev/null; then
        # Add some spacing
        echo -e "\n"
        echo -e "\e[1;33mMounted Filesystems:\e[0m"
        findmnt -D -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL,USE%,OPTIONS
    else
        echo -e "\e[1;33mMounted Filesystems:\e[0m"
        df -hT
        echo -e "\e[1;33mMount Options:\e[0m"
        mount | sort
    fi
    # Store formatted data for summary
    filesystems_summary=$(df -hT | tail -n +2 | awk '{print $NF " (" $1 ", " $2 ", " $6 ")" }' | tr '\n' '\n')
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display /etc/fstab contents
fstab_info() {
    echo -e "\n\n\e[1;34m[+] Gathering /etc/fstab Information\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    if [ -r /etc/fstab ]; then
        echo -e "\e[1;33m/etc/fstab Contents:\e[0m"
        cat /etc/fstab | grep -v '^#' | grep -v '^$' | while read line; do
            if echo "$line" | grep -qE 'noexec|nosuid|nodev'; then
                echo -e "\e[1;31m$line (Restricted options)\e[0m"
            else
                echo "$line"
            fi
        done
    else
        echo -e "\e[1;31m/etc/fstab not readable\e[0m"
    fi
    # Store formatted data for summary
    fstab_summary=$(cat /etc/fstab 2>/dev/null | grep -v '^#' | grep -v '^$' | tr '\n' '; ')
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
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
    file_extensions=".xls .xls* .xltx .csv .od* .doc .doc* .pdf .pot .pot* .pp* .key .conf .config .cnf .sh .backup .bak .pem"

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

# search and print content of readable mails
check_mail() {
    echo -e "\n\n\e[1;34m[+] Checking for Readable Emails in /var/mail/\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    mail_found=0

    # Loop through all mailboxes in /var/mail/
    for mailbox in /var/mail/*; do
        if [ -f "$mailbox" ] && [ -r "$mailbox" ]; then
            echo -e "\e[1;33m[!] Found Readable Mailbox:\e[0m $mailbox"
            echo -e "\e[1;36m[+] Full Content of $mailbox:\e[0m"
            cat "$mailbox" | sed 's/^/    /'
            echo -e "\e[1;35m----------------------------------------\e[0m"
            mail_found=1
        fi
    done

    if [ $mail_found -eq 0 ]; then
        echo -e "\e[1;31m[-] No readable mailboxes found in /var/mail/.\e[0m"
        mail_summary="No readable mailboxes found in /var/mail/."
    else
        mail_summary="Readable emails found in /var/mail/. Review needed."
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
        matches=$(grep --color=always "password\|pass" "$file" 2>/dev/null | grep -v "#")
        if [ -n "$matches" ]; then
            echo -e "\n\e[1;33m[!] File:\e[0m $file"
            echo "$matches" | sed 's/^/ /'
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

# Function to search for potential credentials in log files
search_credentials_in_logs() {
    echo -e "\n\n\e[1;34m[+] Searching for Credentials in Log Files\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"

    log_files=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/syslog"
        "/var/log/httpd/access_log"
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/mysql/error.log"
        "/var/log/mariadb/mariadb.log"
        "/var/log/postgresql/postgresql.log"
        "/var/log/samba/log.smbd"
    )

    # Improved regex pattern to capture both key and value
    patterns="([a-zA-Z0-9_-]*(user|username|login|pass|password|passwd|pw|token|secret)[a-zA-Z0-9_-]*)=([^&\" ]+)"

    credentials_found=0

    for log in "${log_files[@]}"; do
        if [ -f "$log" ]; then
            matches=$(grep -Eio "$patterns" "$log" 2>/dev/null | sort -u)  # Sort and remove duplicates
            if [ -n "$matches" ]; then
                echo -e "\e[1;33m[!] Potential Credentials Found in:\e[0m $log"
                echo "$matches" | sed 's/^/    /'
                credentials_found=1
            fi
        fi
    done

    if [ $credentials_found -eq 0 ]; then
        echo -e "\e[1;31m[-] No credentials found in log files.\e[0m"
        log_credentials_summary="No credentials found in log files."
    else
        log_credentials_summary="Potential credentials found in log files. Review needed."
    fi

    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
}

# Function to display processes running as root
root_processes_info() {
    echo -e "\n\n\e[1;34m[+] Gathering Processes Running as Root\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    echo -e "\e[1;33mProcesses Running as Root:\e[0m"
    ps aux | grep "^root" | while read -r line; do
        if echo "$line" | grep -qE "systemd|apache|mysql|postgres|ssh|ftp|smb|http|nginx|docker|lxd"; then
            echo -e "\e[1;31m$line (Potentially exploitable service)\e[0m"
        else
            echo "$line"
        fi
    done
    # Store formatted data for summary
    root_processes_summary="Root processes: $(ps aux | grep -c "^root")"
    echo -e "\n\e[1;32m--------------------------------------------------------------------------\e[0m"
}

print_summary() {
    echo -e "\n\e[1;34m[+] Summary\e[0m"
    echo -e "\e[1;32m--------------------------------------------------------------------------\e[0m"
    
    highlight_summary() {
        local summary_text=$1
        if echo "$summary_text" | grep -q "Review needed"; then
            echo -e "\e[1;31m$summary_text\e[0m"
        else
            echo "$summary_text"
        fi
    }

    echo -e "\e[1;33m[OS Information]:\e[0m $os_info_summary"
    
    # Format user information properly with new lines
    echo -e "\e[1;33m[User Information]:\e[0m"
    echo -e "$user_info_summary" | while IFS= read -r line; do echo " $line"; done
    
    echo -e "\e[1;33m[PATH Information]:\e[0m $path_info_summary"
    echo -e "\e[1;33m[Sudo Privileges]:\e[0m $(highlight_summary "$sudo_priv_summary")"
    echo -e "\e[1;33m[Environment Variables]:\e[0m $(highlight_summary "$env_vars_summary")"
    echo -e "\e[1;33m[SUID Binaries]:\e[0m $(highlight_summary "$suid_summary")"
    echo -e "\e[1;33m[SGID Binaries]:\e[0m $(highlight_summary "$sgid_summary")"
    echo -e "\e[1;33m[Cron Jobs]:\e[0m $(highlight_summary "$cron_summary")"
    echo -e "\e[1;33m[Capabilities]:\e[0m $(highlight_summary "$capabilities_summary")"
    echo -e "\e[1;33m[Writable Files]:\e[0m $(highlight_summary "$writable_files_dirs_summary")"
    echo -e "\e[1;33m[Interesting Files]:\e[0m $(highlight_summary "$interesting_files_summary")"
    echo -e "\e[1;33m[Sensitive Content]:\e[0m $(highlight_summary "$sensitive_content_summary")"
    echo -e "\e[1;33m[SSH Private Keys]:\e[0m $(highlight_summary "$ssh_keys_summary")"
    echo -e "\e[1;33m[Log Credentials]:\e[0m $(highlight_summary "$log_credentials_summary")"
    echo -e "\e[1;33m[Email Readability]:\e[0m $(highlight_summary "$mail_summary")"
    echo -e "\e[1;33m[Docker Detection]:\e[0m $docker_summary"
    echo -e "\e[1;33m[Systemd Configurations]:\e[0m $(highlight_summary "$systemd_summary")"
    echo -e "\e[1;33m[Filesystem Information]:\e[0m $filesystems_summary"
    echo -e "\e[1;33m[/etc/fstab Information]:\e[0m $fstab_summary"
    echo -e "\e[1;33m[Root Processes]:\e[0m $root_processes_summary"
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

# Run Linux Exploit Suggester
run_les

# Add some spacing
echo -e "\n"

# enum current user and group info
user_info

# Add some spacing
echo -e "\n"

# Function to display logged in users and last login information
logged_users_info

# Add some spacing
echo -e "\n"

# enum sudo check
sudo_check

# Add some spacing
echo -e "\n"

# Show PATH variable info
path_info

# Add some spacing
echo -e "\n"

# Show shell history
history_info

# Add some spacing
echo -e "\n"

# Function to display /etc/hosts contents
hosts_file

# Add some spacing
echo -e "\n"

# Show network intefaces
network_interfaces

# Add some spacing
echo -e "\n"

# Display listening ports and associated services
listening_ports

# Add some spacing
echo -e "\n"

# Show the routing table
routing_table

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

# show info about mounted filesystems
filesystems_info

# Add some spacing
echo -e "\n"

# show info about /etc/fstab
fstab_info

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

# search and print content of readable mails
check_mail

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

# search for potential credentials in log files
search_credentials_in_logs

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

# display processes running as root
root_processes_info

# Add some spacing
echo -e "\n"

# Call the summary function
print_summary