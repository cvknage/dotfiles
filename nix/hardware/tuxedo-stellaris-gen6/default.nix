# Hardware for "penguin-tuxedo" (Tuxedo Stellaris Gen 6): the parts that
# persist across reinstalls. System identity (hostname, stateVersion) lives in
# contexts/work/system/nixos.nix.
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    # Tuxedo Control Center (fan/charging/battery profiles).
    inputs.tuxedo-nixos.nixosModules.default
  ];

  # GPU tools for the NVIDIA dGPU.
  environment.systemPackages = with pkgs; [
    nvtopPackages.full # NVTOP stands for Neat Videocard TOP, a (h)top like task monitor for GPUs and accelerators.
    nvitop # An interactive NVIDIA-GPU process viewer and beyond.
    # displaylink # DisplayLink Drivers - this is actually rather annoying, as rebuilds fail becaus a you need to run a command to prefetch the driver.
  ];
}
