# Publishing to the Solar2D Free Plugin Directory

This guide covers submitting a finished plugin to the [Solar2D Free Plugin Directory](https://plugins.solar2d.com/), the catalog the Solar2D build server checks when a developer requires a plugin they have not installed locally. It is the free, open-source distribution channel maintained at [github.com/solar2d/plugins.solar2d.com](https://github.com/solar2d/plugins.solar2d.com).

If you would rather sell or gate your plugin, submit it to the commercial [Solar2D Plugins Marketplace](https://www.solar2dplugins.com/) instead; that has its own [asset packaging guidelines](https://www.solar2dplugins.com/asset-packaging-guidelines) and is out of scope here.

For building the binaries this guide assumes you have, see [BUILDING.md](BUILDING.md).

## Table of Contents

- [How the directory works](#how-the-directory-works)
- [Prerequisites](#prerequisites)
- [Two ways to host the binaries](#two-ways-to-host-the-binaries)
- [Route A: a repository under the solar2d organization](#route-a-a-repository-under-the-solar2d-organization)
- [Route B: your own repository](#route-b-your-own-repository)
- [The directory entry](#the-directory-entry)
- [Version targeting](#version-targeting)
- [Using a published plugin](#using-a-published-plugin)
  - [Pinning a specific version](#pinning-a-specific-version)
- [Redirecting to your own store](#redirecting-to-your-own-store)
- [References](#references)

## How the directory works

The directory does not host your binaries. It is a catalog of pointers. Each plugin is one small JSON file under [`plugins/`](https://github.com/solar2d/plugins.solar2d.com/tree/master/plugins) that records the GitHub account holding the releases, your `publisherId`, the Lua plugin name, the latest release tag, and which Solar2D builds and platforms you ship. A build step in that repository aggregates all of those files into a single `plugins.json` served from `https://plugins.solar2d.com/plugins.json`.

When a developer builds an app whose `build.settings` requires your plugin, the Solar2D build server:

1. Fetches `plugins.json` and looks your plugin up by `publisherId` and name.
2. Picks the newest Solar2D build entry that is less than or equal to the build the developer is using (see [Version targeting](#version-targeting)).
3. Downloads the matching tarball directly from the GitHub Releases of the repository the entry points at.

The download URL the build server constructs is:

```text
https://github.com/<ghAccount>/<publisherId>-<pluginName>/releases/download/<releaseTag>/<solar2dBuild>-<platform>.tgz
```

Two consequences follow from that URL, and both are hard requirements:

- The repository holding the releases must be named `<publisherId>-<pluginName>`, for example `com.xedur-plugin.hello`. The directory tooling derives `publisherId` and the plugin name by splitting the repository name on the first hyphen.
- Each release asset must be named `<solar2dBuild>-<platform>.tgz`, for example `2025.3726-win32-sim.tgz`. The Solar2D build number must be in `YYYY.NNNN` form.

## Prerequisites

- A `publisherId` you control. Reverse-domain form is the convention (`com.yourname`), and it must match the `publisherId` you set in `metadata.json` and that users will put in their `build.settings`.
- A finished build of the plugin from the `Build Plugin` workflow, so you have its `plugin-distribution` artifact and its GitHub Release.

At minimum you must ship a Lua stub for every platform you do not implement natively, so that developers can call your API on any target. This template already builds a `lua` fallback tarball for that purpose.

## Two ways to host the binaries

| | Route A | Route B |
|---|---|---|
| Repository with the releases | `solar2d/<publisherId>-<pluginName>`, created for you | `<your account>/<publisherId>-<pluginName>`, created by you |
| How a release is made | You push the built `plugins/` tree; that repository's own workflow creates the release | This template's `Build Plugin` workflow creates the release |
| Release tag | `v<run number>`, counted by that repository | `v<pluginVersion>` from `metadata.json` |
| Directory entry | Written and updated automatically | You add it with a pull request |

Route A is the one the [directory README](https://github.com/solar2d/plugins.solar2d.com) describes. Route B keeps everything in a repository you own. The README does not describe it, so whether your pull request is accepted is up to the directory's maintainers; the directory does hold entries hosted this way.

## Route A: a repository under the solar2d organization

1. Open a [New Plugin Repo Request](https://github.com/solar2d/plugins.solar2d.com/issues/new/choose) on the directory repository. The form asks for a description of the plugin, the `publisherId` you want, and the plugin name (the Lua module name, for example `plugin.hello`).
2. When a maintainer approves the request, a repository named `solar2d/<publisherId>-<pluginName>` is created from the [plugin template](https://github.com/solar2d/plugin-template) and you are added to it with push access.
3. Run the `Build Plugin` workflow here and download its `plugin-distribution` artifact. It holds a `<solar2dBuild>/<platform>/` tree, for example `2025.3726/win32-sim/`.
4. Clone the `solar2d/<publisherId>-<pluginName>` repository, copy that tree into its `plugins/` folder (so the files end up at `plugins/2025.3726/win32-sim/...`), then commit and push to its default branch.

The push triggers that repository's own workflow, which packs every `plugins/<solar2dBuild>/<platform>/` folder into a `<solar2dBuild>-<platform>.tgz` asset, creates a release tagged `v<run number>`, and asks the directory to update your entry. You do not write the directory entry yourself on this route.

The release tag here is a counter, not your `pluginVersion`. A developer who pins your plugin to a version (see [Pinning a specific version](#pinning-a-specific-version)) uses that `v<run number>` tag.

## Route B: your own repository

1. Name your plugin's GitHub repository `<publisherId>-<pluginName>` (for example `com.xedur-plugin.hello`).
2. Bump `pluginVersion` in `metadata.json` and run the `Build Plugin` workflow. It attaches the `<solar2dBuild>-<platform>.tgz` tarballs to a release tagged `v<pluginVersion>`, which is the asset naming and layout the directory expects. See [BUILDING.md](BUILDING.md#releases).
3. Confirm a tarball is reachable. With a browser or `curl`, the URL pattern above should download the file. If it 404s, the directory will fail to fetch your plugin for users.
4. Add your entry to the directory with a pull request, as described in the next section.

If you build by hand, create the per-platform `data.tgz` tarballs as described in [BUILDING.md](BUILDING.md#manual-setup-from-local-builds), rename each to `<solar2dBuild>-<platform>.tgz`, and attach them all to a single GitHub Release. The release tag is your plugin version (for example `v1.0.0`); the build number lives in the asset names, not the tag.

## The directory entry

Your entry is a single JSON file at `plugins/<publisherId>_<pluginName>.json` (note the underscore separating publisher and name in the file name, while the repository name uses a hyphen). For this sample that file would be `plugins/com.xedur_plugin.hello.json`.

On route A the directory writes this file for you from the latest release. On route B you add it yourself. Its shape is:

```json
{
    "ghAccount": "XeduR",
    "publisherId": "com.xedur",
    "plugin": "plugin.hello",
    "latest": "v1.0.0",
    "supported": {
        "2025.3726": [
            "android",
            "appletvos",
            "appletvsimulator",
            "iphone",
            "iphone-sim",
            "linux",
            "lua",
            "mac-sim",
            "macos",
            "web",
            "win32",
            "win32-sim"
        ]
    }
}
```

| Field | Meaning |
|-------|---------|
| `ghAccount` | The GitHub account or org that owns the `<publisherId>-<pluginName>` release repository: `solar2d` on route A, your own account on route B. |
| `publisherId` | Your reverse-domain publisher id. |
| `plugin` | The Lua module name, e.g. `plugin.hello`. |
| `latest` | The release tag the build server downloads from: `v<run number>` on route A, `v<pluginVersion>` (e.g. `v1.0.0`) on route B. |
| `supported` | A map of Solar2D build number to the list of platforms you ship for that build. The keys must be `YYYY.NNNN`. |

The platform names match the per-platform folders this template produces: `win32-sim`, `win32`, `mac-sim`, `macos`, `linux`, `iphone`, `iphone-sim`, `appletvos`, `appletvsimulator`, `android`, `web`, and the universal `lua` fallback. A plugin whose `platforms` list in `metadata.json` is shorter produces fewer of them.

## Version targeting

The keys in `supported` are minimum Solar2D build numbers, not your plugin's version. When a developer builds with Solar2D build `N`, the build server selects the highest `supported` key that is less than or equal to `N`, then downloads that build's tarballs. So a single entry of `2025.3726` makes your plugin available to that build and every later one.

Ship a new `supported` key only when you rebuild against a newer Solar2D release or need to break compatibility while keeping older binaries reachable. Keeping the older key lets apps on older Solar2D builds continue to resolve the plugin. The list of Solar2D builds is on the [Solar2D releases page](https://github.com/coronalabs/corona/releases).

This maps directly onto `metadata.json`: `solar2dBuild` is the `supported` key, and on route B `pluginVersion` is the release tag (`latest`).

## Using a published plugin

Once your entry is live, a developer adds the plugin to `build.settings` with no URLs:

```lua
settings =
{
    plugins =
    {
        ["plugin.hello"] =
        {
            publisherId = "com.xedur",
        },
    },
}
```

The build server resolves it from the directory and downloads the right tarball for the target platform and Solar2D build. The local `Solar2DPlugins` directory and `supportedPlatforms` URLs described in [BUILDING.md](BUILDING.md) are only needed before a plugin is in the directory, or for private distribution.

### Pinning a specific version

By default the build server always downloads the release tag recorded as `latest` in the directory entry, so publishing a new release immediately moves every user to it. A developer can pin their app to an exact release with two optional keys in the plugin entry:

```lua
["plugin.hello"] =
{
    publisherId = "com.xedur",
    version = "v1.0.0",
    forceBuild = "2025.3726",
},
```

- `version` replaces the release tag in the download URL, so the build server fetches that exact GitHub Release instead of `latest`. Use the full tag, including the `v` prefix: `v<pluginVersion>` on route B, `v<run number>` on route A.
- `forceBuild` replaces the Solar2D build prefix in the asset name (`<solar2dBuild>-<platform>.tgz`). The matching described under [Version targeting](#version-targeting) still runs first: the entry must have a `supported` key at or below the developer's build, and that key must list the platform.

Both keys only change which of your published files gets downloaded. On route B every `pluginVersion` you ship stays pinnable as its `v<pluginVersion>` tag. For pins to keep working, never delete old releases or their assets.

## Redirecting to your own store

If you maintain your own distribution and only want a discoverable catalog entry, the directory supports a redirect form. Instead of `latest` and `supported`, the entry carries an `error` message shown to developers who try to build with it:

```json
{
    "plugin": "plugin.hello",
    "publisherId": "com.xedur",
    "error": "Not provided by the Solar2D Free directory. Get it at https://example.com/plugins/hello."
}
```

The build server returns the `error` text instead of attempting a download, so use it to point developers at your own store or instructions.

## References

- Solar2D Free Plugin Directory repository and submission README: <https://github.com/solar2d/plugins.solar2d.com>
- Template that route A repositories are created from: <https://github.com/solar2d/plugin-template>
- Existing directory entries to model yours on: <https://github.com/solar2d/plugins.solar2d.com/tree/master/plugins>
- Official Corona/Solar2D plugin submission guide: <https://docs.coronalabs.com/native/plugin/submission.html>
- Solar2D build numbers (releases): <https://github.com/coronalabs/corona/releases>
