{ pkgs, ... }:

{
  home.packages = with pkgs; [ serpl ];
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    # Apps inside tmux should see tmux's own terminfo; truecolor/extkeys are
    # granted via terminal-features in tmux.conf, independent of the outer terminal.
    terminal = "tmux-256color";
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
        # https://github.com/fcsonline/tmux-thumbs
        plugin = tmux-thumbs;
        extraConfig = ''
          # Copy selection to Wayland clipboard (default action — lowercase hint letter)
          set -g @thumbs-command     'echo -n {} | wl-copy'
          # Paste selection into the current pane (opposite action — uppercase hint letter)
          set -g @thumbs-opp-command 'tmux set-buffer -- {} && tmux paste-buffer'

          # prefix+p enters the hints table; the next key selects the hint type.
          bind p switch-client -T hints

          # URLs — mirrors kitty_mod+p>u (copy) / kitty_mod+p>shift+u (paste)
          bind -T hints u run-shell "#{@thumbs-path}/tmux-thumbs --command 'echo -n {} | wl-copy'                       --regexp '(https?://|s?ftp://|file:///)[^ ]+'"
          bind -T hints U run-shell "#{@thumbs-path}/tmux-thumbs --command 'tmux set-buffer -- {} && tmux paste-buffer' --regexp '(https?://|s?ftp://|file:///)[^ ]+'"

          # File paths — mirrors kitty_mod+p>f (copy) / kitty_mod+p>shift+f (paste)
          bind -T hints f run-shell "#{@thumbs-path}/tmux-thumbs --command 'echo -n {} | wl-copy'                       --regexp '(~/|\.?/)[^ ]+'"
          bind -T hints F run-shell "#{@thumbs-path}/tmux-thumbs --command 'tmux set-buffer -- {} && tmux paste-buffer' --regexp '(~/|\.?/)[^ ]+'"

          # Lines — mirrors kitty_mod+p>l (copy) / kitty_mod+p>shift+l (paste)
          # tmux-thumbs has no native "line" type; the default pattern set is used
          bind -T hints l run-shell "#{@thumbs-path}/tmux-thumbs --command 'echo -n {} | wl-copy'"
          bind -T hints L run-shell "#{@thumbs-path}/tmux-thumbs --command 'tmux set-buffer -- {} && tmux paste-buffer'"

          # Words — mirrors kitty_mod+p>w (copy) / kitty_mod+p>shift+w (paste)
          bind -T hints w run-shell "#{@thumbs-path}/tmux-thumbs --command 'echo -n {} | wl-copy'                       --regexp '[a-zA-Z0-9_-]+'"
          bind -T hints W run-shell "#{@thumbs-path}/tmux-thumbs --command 'tmux set-buffer -- {} && tmux paste-buffer' --regexp '[a-zA-Z0-9_-]+'"
        '';
      }
      # Too look at some point, i3 style automatic layouts in tmux
      # https://github.com/jabirali/tmux-tilish
    ];
  };
}
