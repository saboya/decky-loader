# Distributing the unofficial SteamOS 3.10 Preview fix

Branch: `vite-3-10-preview-installer`, derived from `vite-3-10-preview-fix`.

## Publisher setup

Push this branch to `saboya/decky-loader` and enable GitHub Actions in the fork.
The **Publish SteamOS 3.10 Preview installer** workflow builds the patched
Linux x86_64 `PluginLoader` using the existing build workflow, then publishes
the binary, service template, desktop shortcut, and GUI installer script to the
`steamos-3.10-preview` prerelease. No secrets beyond GitHub's built-in token
are required. Nothing is published until the workflow succeeds.

The workflow automatically runs on pushes to this distribution branch. Updates
replace assets in the same prerelease; release notes identify the source commit.
The release tag is a distribution endpoint, not a per-build source revision.

## User experience

Share this download link after the first successful workflow run:

<https://github.com/saboya/decky-loader/releases/download/steamos-3.10-preview/decky_installer.desktop>

On the Deck:

1. Switch to Desktop Mode.
2. Download the shortcut. Firefox may append `.download`; remove that suffix.
3. Move it to the Desktop and double-click it, allowing execution if prompted.
4. Accept the unofficial-build warning, enter the admin password (or follow
   Decky's existing temporary-password flow), and select **install 3.10 preview fix**.
5. Return to Gaming Mode. Restart Steam or reboot if needed.

The shortcut downloads the GUI installer from this fork's preview release,
not the upstream installer. The script is adapted from
[`SteamDeckHomebrew/decky-installer/gui/user_install_script.sh`](https://github.com/SteamDeckHomebrew/decky-installer/blob/main/gui/user_install_script.sh)
under GPL-2.0, with the normal password dialogs, progress UI, service setup,
and uninstall options retained. The repository's GPL license applies.

Only the fixed preview build is offered. The installer verifies GitHub's SHA-256
digest and the ELF header before stopping the old loader. It preserves the
services directory, plugins, and settings, and saves the previous executable as
`~/homebrew/services/PluginLoader.before-preview-fix`. The service template is
downloaded from the same release rather than upstream `main`.

This is an experimental build for x86_64 Steam Decks, not an official Decky
release. No manual frontend build, artifact extraction, SSH, or extra bridge
service is needed by users. See [compatibility limitations](VITE_COMPATIBILITY.md).

## Updates and recovery

Re-run this shortcut to install updated preview assets. Decky's normal updater
does not track this custom release tag; do not use it to update this preview
build. Use the official installer to return to official Decky releases.

For the development Deck that still has the temporary bridge installed, disable
`decky-vite-compat.service` after installing the integrated binary, then restart
Steam, as described in [the migration notes](VITE_COMPATIBILITY.md).

To restore the previous executable manually in Konsole:

```sh
sudo systemctl stop plugin_loader.service
sudo cp -a ~/homebrew/services/PluginLoader.before-preview-fix ~/homebrew/services/PluginLoader
sudo systemctl start plugin_loader.service
```

Restart Steam afterward. The backup covers the executable, not a full service
configuration rollback. This installer has static checks but has not yet been
tested end-to-end using a published release; test that flow before public sharing.
