#!/bin/zsh
# Static Master Driver

# --- KEEP MAC AWAKE & PREVENT WI-FI DROPS ---
caffeinate -d -i -m -s -u &
caff_pid=$!
# Ensure caffeinate is killed when script exits
trap "kill $caff_pid 2>/dev/null" EXIT 

onboardingScriptsUrl="https://github.com/Bandiusha/Intune_MacOS/raw/refs/heads/main/onboarding_scripts.zip" 
swiftdialogfolder="/Library/Application Support/Microsoft/IntuneScripts/Swift Dialog"
tempdir="/private/tmp/onboarding"

mkdir -p "$tempdir"
cd "$tempdir"
curl -sL ${onboardingScriptsUrl} -o "onboarding.zip"
unzip -qq -o onboarding.zip

mkdir -p "$swiftdialogfolder"

find "$tempdir" -name "icons" -exec cp -Rf {} "$swiftdialogfolder/" \; 2>/dev/null
find "$tempdir" -name "swiftdialog.json" -exec cp -f {} "$swiftdialogfolder/" \; 2>/dev/null

ui_script=$(find "$tempdir" -name "1-installSwiftDialog.zsh" | head -n 1)
chmod +x "$ui_script"
"$ui_script" & 

echo "Waiting for UI..."
timeout=0
until pgrep -i "dialog" &>/dev/null || [ $timeout -eq 15 ]; do
    sleep 1
    ((timeout++))
done

if ! pgrep -i "dialog" &>/dev/null; then
    echo "$(date) | ERROR: UI failed to appear. Aborting."
    exit 1
fi

script_path=$(find "$tempdir" -name "scripts" -type d | head -n 1)
scripts_to_run=($script_path/*.*)
total_scripts=${#scripts_to_run[@]}
current_count=0

declare -A titles
titles=( ["01"]="Company Portal" ["02"]="Microsoft Office" ["03"]="Microsoft Defender" ["04"]="Adobe Acrobat Reader" ["05"]="Google Chrome" ["06"]="Google Drive" ["07"]="Bitwarden" ["08"]="Microsoft Remote Help" )

for script in "${scripts_to_run[@]}"; do
    current_count=$((current_count + 1))
    progress_percent=$(( (current_count * 100) / total_scripts ))
    
    prefix=$(basename "$script" | cut -c 1-2)
    display_name="${titles[$prefix]}"

    # --- NETWORK GUARD ---
    while ! /sbin/ping -c 1 captive.apple.com &> /dev/null; do
        echo "progresstext: Network dropped. Waiting for Wi-Fi to reconnect..." >> /var/tmp/dialog.log
        sleep 5
    done
    # ---------------------

    echo "listitem: title: ${display_name}, status: wait, statustext: Installing..." >> /var/tmp/dialog.log
    echo "progresstext: Installing ${display_name} (${current_count} of ${total_scripts})..." >> /var/tmp/dialog.log
    
    # --- SANITIZER FIX ---
    # Strips invisible Windows carriage returns (\r) so the Mac doesn't crash on execution
    tr -d '\r' < "$script" > "${script}.clean"
    mv "${script}.clean" "$script"
    chmod +x "$script"
    # ---------------------
    
    "$script" 
    exit_code=$? 
    
    if [ $exit_code -eq 0 ]; then
        echo "listitem: title: ${display_name}, status: success, statustext: Installed" >> /var/tmp/dialog.log
    else
        echo "listitem: title: ${display_name}, status: fail, statustext: Failed" >> /var/tmp/dialog.log
    fi
    
    echo "progress: ${progress_percent}" >> /var/tmp/dialog.log
done