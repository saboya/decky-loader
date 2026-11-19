# Steam Vite compatibility (experimental)

The November 2026 Steam beta replaced Webpack with Vite/Rolldown. Decky's
original frontend fails at `window.webpackChunksteamui.push` on that client.

## Normal installation and build

Users install Decky using the existing `.desktop` installer or shell installer.
There is no additional installer, service, port, build flag, or Python dependency.
These installers must download a release artifact containing this change;
editing a local clone does not update the public releases they download.

Developers build as usual:

```sh
cd frontend
pnpm install --frozen-lockfile --ignore-scripts
pnpm build
pnpm typecheck
```

The standard build writes the original frontend to `backend/decky_loader/static/`
and the compatibility frontend to `backend/decky_loader/static/vite/`.
The existing PyInstaller configuration includes that entire directory and
automatically imports the backend compatibility helper into `PluginLoader`.

At injection time `backend/decky_loader/vite.py` checks the **target Steam UI**:

- Webpack available: load the original `frontend/index.js`.
- Otherwise, once Steam initializes: inspect the live QAM module scope using
  Decky's existing CEF debugger connection, populate its module cache, and load
  `frontend/vite/index.js` from Decky's existing HTTP server.

This is runtime detection, not a SteamOS-version or build-machine check. A Steam
channel change is handled on the next UI injection without reinstalling Decky.
The normal reinjection and crash-fallback paths are retained.

## Validation and limitations

The compatibility frontend was tested on SteamOS 3.10.1, Steam beta build
`1795048523`, Decky v3.3.1-pre1, and @decky/ui 4.16.4, initially through a
temporary bridge. The user confirmed the QAM contents rendered and all five
installed plugins loaded. That test does not validate every plugin feature.

The integrated binary still needs an end-to-end packaged-installation test.
Unit tests cover selecting the original frontend, transferring the Vite cache,
and debugger failures. Build and TypeScript checks cover both frontend variants.

Remaining limitations:

- Debugger scope exposure and the QAM diagnostic string may change in future
  Steam builds.
- Flattened module namespaces lose Webpack sibling grouping; some component
  heuristics remain approximate.
- Several CSS maps are only partially reconstructed, so styling may differ.
- The error-reporting boundary hook is not yet identified on the new client.
- Dialog discovery emits caught invalid-hook-call errors for two candidates.

## Migrating from the temporary development workaround

The first prototype installed `decky-vite-compat.service` in the user's systemd
directory. That service is **not part of the integrated solution**. Once the
patched `PluginLoader` binary is installed, disable the old workaround:

```sh
systemctl --user disable --now decky-vite-compat.service
```

Then restart Steam. Do not disable the workaround before deploying the patched
loader if it is still needed to keep Decky's current UI functional.
