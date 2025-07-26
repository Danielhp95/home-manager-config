{ pkgs, ... }:

# TODO:
# - images on yazi don't show up (they do in wezterm!)
{
  home.packages = [ pkgs.gitmux ];
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "kitty"; # I don't like this hardcoding!
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-processes 'vim nvim ssh npm ~ipython'
          set -g @resurrect-capture-pane-contents 'on' # Restore pane contents
          set -g @resurrect-auto-restore 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-boot 'on'
          set -g @continuum-restore 'on' # Continuum auto restore
          set -g @continuum-save-interval '5' # Save every 5 mins
        '';
      }
      {
        plugin = tmux-floax;
        extraConfig = ''
          set -g @floax-bind 'F'
          set -g @floax-width '90%'
          set -g @floax-height '90%'
        '';
      }
      {
        # https://github.com/alexwforsythe/tmux-which-key
        plugin = tmux-which-key;
        extraConfig = ''
          set -g @tmux-which-key-xdg-enable 1;
          set -g @tmux-which-key-disable-autobuild 1
        '';
      }
      # Too look at some point, i3 style automatic layouts in tmux
      # https://github.com/jabirali/tmux-tilish
    ];
  };
}
