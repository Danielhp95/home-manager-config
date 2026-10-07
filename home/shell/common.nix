# Strings the zsh and the nushell configuration both quote.
{
  # What zoxide's interactive picker (zi, `z foo<Space><Tab>`) adds to the
  # ambient fzf options. Its lines are "score path", hence {2..}; a bare
  # --icons would eat the path as its WHEN value.
  zoxideFzfOpts = "--height 40% --tmux center,70%,60% --preview-window=down --preview 'eza -1 --color=always --icons=always {2..}'";
}
