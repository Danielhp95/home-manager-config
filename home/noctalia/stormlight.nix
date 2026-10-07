# The battery warnings, in Stormlight wording.
{ config, pkgs, ... }:
let
  noctaliaPkg = config.programs.noctalia.package;

  # Stormlight wording for noctalia's battery warnings (low at the threshold
  # and 5%, critical at 2%). `battery` is also the laptop's {device} label.
  stormlightStrings = pkgs.writeText "stormlight-strings.json" (
    builtins.toJSON {
      battery = "Stormlight";
      battery-low-title = "Stormlight running low";
      battery-low-body = "{device}: {percent}%. The spheres are going dun; set them out for the next highstorm.";
      battery-critical-title = "Life before death";
      battery-critical-body = "{device}: {percent}%. Your battery is dead. But I'll see what I can do.";
    }
  );

  # noctalia's strings have no per-string override, so this is its asset
  # bundle as a symlink tree with en.json patched, used via
  # NOCTALIA_ASSETS_DIR. Fails the build if upstream renames a key.
  stormlightAssets =
    pkgs.runCommandLocal "noctalia-assets-stormlight" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        assets=${noctaliaPkg}/share/noctalia/assets
        cp -rs $assets $out
        chmod u+w $out/translations
        rm $out/translations/en.json
        jq --slurpfile s ${stormlightStrings} '
          (($s[0] | keys) - (.notifications.internal | keys)) as $missing
          | if $missing != [] then error("unknown keys: \($missing)") else . end
          | .notifications.internal += $s[0]
        ' $assets/translations/en.json > $out/translations/en.json
      '';
in
{
  systemd.user.services.noctalia.Service.Environment = [
    "NOCTALIA_ASSETS_DIR=${stormlightAssets}"
  ];

  # First low-battery warning; noctalia adds fixed 5% and 2% levels.
  programs.noctalia.settings.battery.warning_threshold = 20;
}
