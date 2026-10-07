# hyprland-preview-share-picker from its flake input, with one patch. Bound as
# pkgs.hyprland-preview-share-picker in pkgs/overlay.nix.
#
# The picker reads `hyprctl monitors -j` and `clients -j` through hyprland-rs,
# which requires an `id` in every workspace object. Hyprland 0.56 prints one
# only for a numbered workspace, so each monitor's empty specialWorkspace
# fails the parse and the Outputs tab is never built; a window on a special
# or named workspace does the same to the Windows tab. --replace-fail breaks
# the build when the crate version moves: check then whether it still needs it.
{ picker }:
picker.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace "$cargoDepsCopy"/hyprland-0.4.0-beta.2/src/data/regular.rs \
      --replace-fail 'pub id: WorkspaceId,' '#[serde(default)] pub id: WorkspaceId,'
  '';
})
