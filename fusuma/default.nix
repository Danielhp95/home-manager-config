{pkgs, inputs, ...}:
{
  services.fusuma = {
    enable = true;
    extraPackages = with pkgs; [ ydotool ];
    # package = inputs.anyrun.packages.${pkgs.system}.anyrun-with-all-plugins;
    settings = builtins.readFile ./config.yaml;
  };
  home.packages = with pkgs; [
    fusuma
  ];

# gesture swipe up 3 hyprctl dispatch fullscreen 1
# gesture swipe down 3 hyprctl dispatch fullscreen 1
# gesture swipe up 4 hyprctl dispatch fullscreen 0
# gesture swipe down 4 hyprctl dispatch fullscreen 0
# gesture pinch clockwise hyprctl dispatch splitratio 0.1
# gesture pinch anticlockwise hyprctl dispatch splitratio -0.1
# gesture pinch in 4 hyprctl dispatch killactive
# gesture pinch out 4 hyprctl dispatch exec kitty
# gesture swipe left_up 2 hyprctl dispatch workspace 1
# gesture swipe left_down 2 hyprctl dispatch workspace 2
# gesture swipe right_up 2 hyprctl dispatch workspace 3
# gesture swipe right_down 2 hyprctl dispatch workspace 4
}
