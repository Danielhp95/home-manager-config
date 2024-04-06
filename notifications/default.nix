{ pkgs, ... }:
{
  home.packages = with pkgs; [
    swaynotificationcenter
  ];
  home.file.".config/swaync/config.json".text = ''
{
	"$schema": "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json",
  "timeout-critical": 20,
  "timeout": 10,
  "timeout-low": 5,

  "script-fail-notify": true,

  "widgets": [
    "mpris"
  ],
  "widget-config": {
    "mpris": {
      "image-size": 100,
      "image-radius": 35
    },
    "dnd": {
			"text": "Do Not Disturb"
		}
  }
}
'';
}
