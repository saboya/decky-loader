#!/bin/bash

# Adapted from SteamDeckHomebrew/decky-installer (GPL-2.0); see LICENSE.
# This installer deliberately targets only the fork's fixed preview release.
set -o pipefail
LOADER_REPO="saboya/decky-loader"
RELEASE_TAG="steamos-3.10-preview"

# Check dependencies before opening dialogs or changing anything.
for dependency in zenity jq curl; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Decky installer requires %s, but it was not found. Run from SteamOS Desktop Mode.\n' "$dependency" >&2
        exit 1
    fi
done

if (( EUID != 0 )); then
    # Zenity can return 1 for both cancellation and a display error.
    dialog_error=$(zenity --title="Unofficial Decky — SteamOS 3.10 Preview" --question --width=500 \
        --text="This installs saboya's experimental SteamOS 3.10 Preview fix, NOT an official Decky release.\n\nPlugins and settings are preserved. Some plugin features may not work.\n\nContinue?" 2>&1)
    dialog_status=$?
    if (( dialog_status != 0 )); then
        if (( dialog_status == 1 )) && [[ -z "$dialog_error" ]]; then
            exit 0
        fi
        printf 'Could not open the installer dialog (Zenity exit %s). Run from SteamOS Desktop Mode.\n%s\n' \
            "$dialog_status" "$dialog_error" >&2
        exit "$dialog_status"
    fi
fi

# if a password was set by decky, this will run when the program closes
temp_pass_cleanup() {
  echo $PASS | sudo -S -k passwd -d deck
}

# removes unhelpful GTK warnings
zen_nospam() {
  zenity 2> >(grep -v 'Gtk' >&2) "$@"
}

# if the script is not root yet, get the password and rerun as root
if (( $EUID != 0 )); then
    PASS_STATUS=$(passwd -S deck 2> /dev/null)
    if [ "$PASS_STATUS" = "" ]; then
        echo "Deck user not found. Continuing anyway, as it probably just means user is on a non-steamos system."
    fi

    if [ "${PASS_STATUS:5:2}" = "NP" ]; then # if no password is set
        if ( zen_nospam --title="Decky Installer" --width=300 --height=200 --question --text="You appear to have not set an admin password.\nDecky can still install by temporarily setting your password to 'Decky!' and continuing, then removing it when the installer finishes\nAre you okay with that?" ); then
            yes "Decky!" | passwd deck # set password to Decky!
            trap temp_pass_cleanup EXIT # make sure that password is removed when application closes
            PASS="Decky!"
        else exit 1; fi
    else
        # get password
        FINISHED="false"
        while [ "$FINISHED" != "true" ]; do
            PASS=$(zen_nospam --title="Decky Installer" --width=300 --height=100 --entry --hide-text --text="Enter your sudo/admin password") || exit $?
            if ( echo "$PASS" | sudo -S -k true ); then
                FINISHED="true"
            else
                zen_nospam --title="Decky Installer" --width=150 --height=40 --info --text "Incorrect Password"
            fi
        done
    fi

    if [[ "$USER" != "deck" ]]; then
        zen_nospam --title="Decky Installer" --width=300 --height=100 --warning --text "You appear to not be on a deck.\nDecky should still mostly work, but you may not get full functionality."
    fi

    echo "$PASS" | sudo -E -S -k bash "$0" "$@" # rerun script as root
    exit $?
fi

# all code below should be run as root
USER_DIR="$(getent passwd $SUDO_USER | cut -d: -f6)"
if [[ -z "$USER_DIR" || -z "$SUDO_USER" ]]; then
    echo "Run this installer as your normal desktop user, not directly as root."
    exit 1
fi
HOMEBREW_FOLDER="${USER_DIR}/homebrew"

# if decky is already installed, then add 'uninstall' and 'wipe' option
if [[ -f "${USER_DIR}/homebrew/services/PluginLoader" ]] ; then
    OPTION=$(zen_nospam --title="Decky Installer" --width=750 --height=400 --list --radiolist --text "Select Option:" --hide-header --column "Buttons" --column "Choice" --column "Info" \
    TRUE "install 3.10 preview fix" "Unofficial build from saboya/decky-loader" \
    FALSE "uninstall decky loader" "Will keep config intact" \
    FALSE "wipe decky loader" "Will NOT keep config intact") || exit $?
else
    OPTION=$(zen_nospam --title="Decky Installer" --width=750 --height=300 --list --radiolist --text "Select branch to install:" --hide-header --column "Buttons" --column "Choice" --column "Info" \
    TRUE "install 3.10 preview fix" "Unofficial build from saboya/decky-loader") || exit $?
fi

[[ -n "$OPTION" ]] || exit 0

# uninstall if uninstall option was selected
if [[ "$OPTION" == "uninstall decky loader" || "$OPTION" == "wipe decky loader" ]] ; then
    (
    echo "20" ; echo "# Disabling and removing services" ;
    sudo systemctl disable --now plugin_loader.service > /dev/null
    sudo rm -f "${USER_DIR}/.config/systemd/user/plugin_loader.service"
    sudo rm -f "/etc/systemd/system/plugin_loader.service"

    echo "40" ; echo "# Removing Temporary Files" ;
    rm -rf "/tmp/plugin_loader"
    rm -rf "/tmp/user_install_script.sh"

    if [ "$OPTION" == "wipe decky loader" ]; then
        echo "60" ; echo "# Deleting homebrew folder" ;
        sudo rm -r "${HOMEBREW_FOLDER}"
    else
        echo "60" ; echo "# Cleaning services folder" ;
        sudo rm "${HOMEBREW_FOLDER}/services/PluginLoader"
    fi

    echo "80" ; echo "# Disabling CEF debugging" ;
    sudo rm "${USER_DIR}/.steam/steam/.cef-enable-remote-debugging"
    sudo rm "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging" 2> /dev/null

    echo "100" ; echo "# Uninstall finished, installer can now be closed";
    ) |
    zen_nospam --progress --auto-close \
  --title="Decky Installer" \
  --width=300 --height=100 \
  --text="Uninstalling..." \
  --percentage=0 \
  --no-cancel
  exit 0
fi

# otherwise, install decky
BRANCH="prerelease"

(
set -e
echo "15" ; echo "# Creating file structure" ;
sudo -u $SUDO_USER  mkdir -p "${HOMEBREW_FOLDER}/plugins"
sudo -u $SUDO_USER  touch "${USER_DIR}/.steam/steam/.cef-enable-remote-debugging"
# if installed as flatpak, put .cef-enable-remote-debugging there
[ -d "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/" ] && sudo -u $SUDO_USER touch "${USER_DIR}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging"

echo "30" ; echo "# Finding latest $BRANCH";
# Release assets are per CPU architecture; the installed binary is always PluginLoader
case "$(uname -m)" in
    x86_64) ASSET="PluginLoader" ;;
    *) echo "This experimental release only supports x86_64 Steam Decks."; exit 1 ;;
esac
RELEASE=$(curl --fail --silent --show-error --location "https://api.github.com/repos/${LOADER_REPO}/releases/tags/${RELEASE_TAG}") || exit 1
VERSION=$(jq -r '.tag_name' <<< ${RELEASE} )
DOWNLOADURL=$(jq -r --arg asset "$ASSET" '.assets[] | select(.name == $asset) | .browser_download_url' <<< ${RELEASE})
# Only replace the existing install once there is something to download
if [ -z "$DOWNLOADURL" ]; then
    zen_nospam --title="Decky Installer" --width=300 --height=100 --error --text "No Decky Loader $BRANCH with a $ASSET build was found, or GitHub could not be reached."
    exit 1
fi
mkdir -p "${HOMEBREW_FOLDER}/services"

echo "45" ; echo "# Installing version $VERSION" ;
# make another zenity prompt while downloading the PluginLoader file, I do not know how this works
STAGING=$(mktemp -d) || exit 1
trap 'rm -f "$STAGING/PluginLoader" "$STAGING/plugin_loader.service"; rmdir "$STAGING"' EXIT
curl --fail --show-error --location "$DOWNLOADURL" --output "$STAGING/PluginLoader" || exit 1
DIGEST=$(jq -r --arg asset "$ASSET" '.assets[] | select(.name == $asset) | .digest // empty' <<< "$RELEASE")
if [[ ! "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    zen_nospam --error --text="GitHub did not provide a SHA-256 digest. Installation aborted."
    exit 1
fi
printf '%s  %s\n' "${DIGEST#sha256:}" "$STAGING/PluginLoader" | sha256sum --check --status || exit 1
[[ "$(head -c 4 "$STAGING/PluginLoader" | od -An -tx1 | tr -d ' \n')" == '7f454c46' ]] || exit 1
# Fetch the service from the same published release before stopping anything.
curl --fail --show-error --location "https://github.com/${LOADER_REPO}/releases/download/${RELEASE_TAG}/plugin_loader-prerelease.service" --output "$STAGING/plugin_loader.service" || exit 1
grep -q '^\[Service\]$' "$STAGING/plugin_loader.service" || exit 1
systemctl stop plugin_loader.service 2>/dev/null || true
if [[ -f "${HOMEBREW_FOLDER}/services/PluginLoader" ]]; then
    cp -a "${HOMEBREW_FOLDER}/services/PluginLoader" "${HOMEBREW_FOLDER}/services/PluginLoader.before-preview-fix" || exit 1
fi
install -m 0755 "$STAGING/PluginLoader" "${HOMEBREW_FOLDER}/services/PluginLoader" || exit 1

echo "60"; echo "Running SELinux fix if it is enabled"
hash getenforce 2>/dev/null && getenforce | grep "Enforcing" >/dev/null && chcon -t bin_t ${HOMEBREW_FOLDER}/services/PluginLoader

echo $VERSION > ${HOMEBREW_FOLDER}/services/.loader.version

echo "70" ; echo "# Killing plugin_loader if it exists" ;
systemctl --user stop plugin_loader 2> /dev/null || true
systemctl --user disable plugin_loader 2> /dev/null || true
systemctl stop plugin_loader 2> /dev/null || true
systemctl disable plugin_loader 2> /dev/null || true

echo "85" ; echo "# Setting up systemd" ;
cp "$STAGING/plugin_loader.service" "${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service"
cat > "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" <<- EOM
[Unit]
Description=SteamDeck Plugin Loader
After=network.target
[Service]
Type=simple
User=root
Restart=always
ExecStart=${HOMEBREW_FOLDER}/services/PluginLoader
WorkingDirectory=${HOMEBREW_FOLDER}/services
Environment=UNPRIVILEGED_PATH=${HOMEBREW_FOLDER}
Environment=PRIVILEGED_PATH=${HOMEBREW_FOLDER}
Environment=LOG_LEVEL=INFO
[Install]
WantedBy=multi-user.target
EOM

# if .service file doesn't exist for whatever reason, use backup file instead
if [[ -f "${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service" ]]; then
    printf "Grabbed latest ${BRANCH} service.\n"
    sed -i -e "s|\${HOMEBREW_FOLDER}|${HOMEBREW_FOLDER}|" "${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service"
    cp -f "${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service" "/etc/systemd/system/plugin_loader.service"
else
    printf "Could not curl latest ${BRANCH} systemd service, using built-in service as a backup!\n"
    rm -f "/etc/systemd/system/plugin_loader.service"
    cp "${HOMEBREW_FOLDER}/services/plugin_loader-backup.service" "/etc/systemd/system/plugin_loader.service"
fi

mkdir -p ${HOMEBREW_FOLDER}/services/.systemd
cp ${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-${BRANCH}.service
cp ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/.systemd/plugin_loader-backup.service
rm ${HOMEBREW_FOLDER}/services/plugin_loader-backup.service ${HOMEBREW_FOLDER}/services/plugin_loader-${BRANCH}.service

systemctl daemon-reload
systemctl start plugin_loader
systemctl enable plugin_loader

# this (retroactively) fixes a bug where users who ran the installer would have homebrew owned by root instead of their user
# will likely be removed at some point in the future
if [ "$SUDO_USER" =  "deck" ]; then
  sudo chown -R deck:deck "${HOMEBREW_FOLDER}"
  sudo chown -R root:root "${HOMEBREW_FOLDER}"/services/*
fi

echo "100" ; echo "# Install finished, installer can now be closed";
) |
zen_nospam --progress --auto-close \
  --title="Decky Installer" \
  --width=300 --height=100 \
  --text="Installing..." \
  --percentage=0 \
  --no-cancel # not actually sure how to make the cancel work properly, so it's just not there unless someone else can figure it out

if [ "$?" -ne 0 ]; then
    zen_nospam --title="Decky Installer" --error --text="Installation failed. Check the terminal output."
    exit 1
fi
