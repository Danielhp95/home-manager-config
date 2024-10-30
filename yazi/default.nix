{ pkgs, ... }: {
  # Hopefully this will work at some point
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };
  home.packages = with pkgs;
    [
      exiftool # Tool to read, write and edit EXIF meta information
    ];
}
