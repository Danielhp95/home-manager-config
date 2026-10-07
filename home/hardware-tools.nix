# Looking at and poking the machine.
{ pkgs, ... }:
{
  home.packages = [
    pkgs.acpi # Laptop battery levels
    pkgs.brightnessctl # Control brightness via CLI
    pkgs.pciutils # For `lspci` command.
    pkgs.nvtopPackages.full # Better `nvidia-smi` that also supports AMD GPUs
    pkgs.powertop # Analyze power consumption for intel based processors
    pkgs.bluetui # Bluetooth tui
    pkgs.android-tools
  ];
}
