#!/bin/zsh
# Static Master Driver - SPEED OPTIMIZED & SECURED

onboardingScriptsUrl="https://github.com/Bandiusha/Intune_MacOS/raw/refs/heads/main/onboarding_scripts_v3.zip" 
swiftdialogfolder="/Library/Application Support/Microsoft/IntuneScripts/Swift Dialog"
tempdir="/private/tmp/onboarding"

mkdir -p "$tempdir"
cd "$tempdir"
curl -sL ${onboardingScriptsUrl} -o "onboarding.zip"
unzip -qq -o onboarding.zip

mkdir -p "$swiftdialogfolder"

# Move files
find "$tempdir" -name "icons" -exec cp -Rf {} "$swiftdialogfolder/" \; 2>/dev/null
find "$tempdir" -name "swiftdialog.json" -exec cp -f {} "$swiftdialogfolder/" \; 2>/dev/null

# Define the UI Script Path
ui_script=$(find "$tempdir" -name "1-installSwiftDialog.zsh" | head -n 1)
chmod +x "$ui_script"
"$ui_script" & 

# Strict UI Guard
echo "Waiting for UI..."
timeout=0
until pgrep -i "dialog" &>/dev/null || [ $timeout -eq 15 ]; do
    sleep 1
    ((timeout++))
done

if ! pgrep -i "dialog" &>/dev/null; then
    echo "$(date) | ERROR: UI failed to appear. Aborting to prevent silent install."
    exit 1
fi

# Drive the Progress Bar and List Items
script_path=$(find "$tempdir" -name "scripts" -type d | head -n 1)
scripts_to_run=($script_path/*.*)
total_scripts=${#scripts_to_run[@]}
current_count=0

declare -A titles
titles=( ["01"]="Company Portal" ["02"]="Microsoft Office" ["03"]="Microsoft Defender" ["04"]="Adobe Acrobat Reader DC" ["05"]="Google Chrome" ["06"]="Google Drive" ["07"]="Bitwarden" ["08"]="Microsoft Remote Help" )

for script in "${scripts_to_run[@]}"; do
    current_count=$((current_count + 1))
    progress_percent=$(( (current_count * 100) / total_scripts ))
    
    prefix=$(basename "$script" | cut -c 1-2)
    display_name="${titles[$prefix]}"

    # Set to wait/spinning
    echo "listitem: title: ${display_name}, status: wait, statustext: Installing..." >> /var/tmp/dialog.log
    echo "progresstext: Installing ${display_name} (${current_count} of ${total_scripts})..." >> /var/tmp/dialog.log
    
    chmod +x "$script"
    "$script" 
    exit_code=$? # Capture whether the app installed correctly or crashed
    
    if [ $exit_code -eq 0 ]; then
        # Update to Success if it actually worked
        echo "listitem: title: ${display_name}, status: success, statustext: Installed" >> /var/tmp/dialog.log
    else
        # Update to Fail (Red X) if it crashed
        echo "listitem: title: ${display_name}, status: fail, statustext: Failed" >> /var/tmp/dialog.log
    fi
    
    echo "progress: ${progress_percent}" >> /var/tmp/dialog.log
done

echo "progresstext: All installations complete!" >> /var/tmp/dialog.log
echo "progress: complete" >> /var/tmp/dialog.log
echo "button1: enable" >> /var/tmp/dialog.log
touch "$swiftdialogfolder/onboarding.flag"