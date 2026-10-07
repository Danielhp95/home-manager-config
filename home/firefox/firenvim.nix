# firenvim: the add-on, and the native-messaging host it talks to. Nothing
# else in the Firefox configuration knows about either.
{
  lib,
  pkgs,
  ...
}:
let
  # What `:call firenvim#install(0)` writes imperatively, built here and run on
  # danvim's nvim (which ships the firenvim plugin).
  firenvimHost =
    let
      nvim = lib.getExe pkgs.danvim;

      # Verbatim from firenvim's s:get_executable_content(): take stdin before
      # the config loads, and keep print() off the protocol's stdout.
      earlyStdio = lib.concatStringsSep "|" [
        "let g:firenvim_config={'globalSettings':{},'localSettings':{'.*':{}}}"
        "let g:firenvim_i=[]"
        "let g:firenvim_o=[]"
        "let g:Firenvim_oi={i,d,e->add(g:firenvim_i,d)}"
        "let g:Firenvim_oo={t->[chansend(2,t)]+add(g:firenvim_o,t)}"
        "let g:firenvim_c=stdioopen({'on_stdin':{i,d,e->g:Firenvim_oi(i,d,e)},'on_print':{t->g:Firenvim_oo(t)}})"
      ];

      # Also verbatim: a failure reaches the browser as a message.
      run = lib.concatStringsSep "|" [
        "try"
        "call firenvim#run()"
        "catch /Unknown function/"
        ''call chansend(g:firenvim_c,["f\n\n\n"..json_encode({"messages":["Your plugin manager did not load the Firenvim plugin for Neovim."],"version":"0.0.0"})])''
        ''call chansend(2,["Firenvim not in runtime path. &rtp="..&rtp])''
        "qall!"
        "catch"
        ''call chansend(g:firenvim_c,["l\n\n\n"..json_encode({"messages": ["Something went wrong when running firenvim. See troubleshooting guide."],"version":"0.0.0"})])''
        "call chansend(2,[v:exception])"
        "qall!"
        "endtry"
      ];

      launcher = pkgs.writeShellScript "firenvim" ''
        dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}/firenvim"
        mkdir -p "$dir"
        chmod 700 "$dir"
        cd "$dir"
        unset NVIM_LISTEN_ADDRESS
        if [ -n "$VIM" ] && [ ! -d "$VIM" ]; then
          unset VIM
        fi
        if [ -n "$VIMRUNTIME" ] && [ ! -d "$VIMRUNTIME" ]; then
          unset VIMRUNTIME
        fi
        exec ${nvim} --headless \
          --cmd ${lib.escapeShellArg earlyStdio} \
          --cmd 'let g:started_by_firenvim = v:true' \
          -c ${lib.escapeShellArg run}
      '';
    in
    pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/firenvim.json" (
      builtins.toJSON {
        name = "firenvim";
        description = "Turn your browser into a Neovim GUI.";
        path = "${launcher}";
        type = "stdio";
        allowed_extensions = [ pkgs.firefox-addons.firenvim.addonId ];
      }
    );
in
{
  programs.firefox = {
    # Linked into ~/.mozilla/native-messaging-hosts.
    nativeMessagingHosts = [ firenvimHost ];
    profiles.default.extensions.packages = [ pkgs.firefox-addons.firenvim ];
  };
}
