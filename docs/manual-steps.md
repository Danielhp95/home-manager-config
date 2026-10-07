# Manual steps

What a rebuild cannot do. Each item names the module whose comments say why.

## On a new machine or a fresh profile

- **Element** (`home/element.nix`): pick the palette's theme once in
  Settings → Appearance. `default_theme` only applies to a profile that never
  chose a theme; the choice lives in account data.
- **Chromium** (`home/chromium.nix`): chrome://settings/appearance → Theme →
  Use GTK, once per profile.
- **Vimium** (`home/firefox/vimium.nix`): Vimium Options → Backup and Restore →
  `~/.local/share/vimium/vimium-settings.json`. Nix cannot write Vimium's
  storage.sync; only the hint and vomnibar CSS is written on each switch.
- **Firefox add-ons without a package** (`home/firefox/default.nix`): GoLinks,
  History Export and reMarkable are not declared. Install them by hand, or
  declare them through `programs.firefox.policies.ExtensionSettings` with an
  AMO `install_url`.
- **fcitx5** (`home/fcitx5/settings.nix`): `~/.config/fcitx5` is a read-only
  store link, so a change made in fcitx5-configtool has to be ported into that
  file.

## After a switch

- **EQ curves** (`hosts/lenovo/audio-eq/`): a switch does not reload them.
  `systemctl --user restart wireplumber`.
- **New Tab Override** (`home/firefox/default.nix`): Firefox imports
  `extensions.settings` only on the add-on's first run. A later edit needs the
  add-on's data reset, or its own options page.
- **Noctalia's plugin list** (`home/noctalia/plugins.nix`):
  `noctalia msg plugins enable/disable` and the settings GUI write a
  `[plugins]` block into `~/.local/state/noctalia/settings.toml`, which then
  replaces the whole Nix list. Delete that block if the Nix list stops
  applying.
- **Noctalia's community plugins** (`home/noctalia/plugins.nix`): they come
  from a `blob:none` clone that noctalia never lazy-fetches. Update with
  `noctalia msg plugins update`. After a bare `git fetch` the catalog comes up
  empty, and a newly enabled plugin can too; pre-warming the plugin's blobs
  (`git cat-file --batch-check`) is the other way out.
- **danvim** (`flake.nix`): a commit in `danvim/` reaches a rebuild only after
  `nix flake update danvim`.
