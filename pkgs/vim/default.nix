{ lib, vimUtils, ... }:
sources: plugins:
lib.genAttrs plugins (name:
  let
    preSrc = sources.${name};
    src = preSrc // {
      version = builtins.substring 0 8 preSrc.version;
    };
  in
  vimUtils.buildVimPlugin src
)
