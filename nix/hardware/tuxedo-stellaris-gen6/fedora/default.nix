# Fedora equivalent of ../nixos/hardware-configuration.nix's boot.kernelParams fix
# (modprobe.d here since kernel cmdline isn't Nix-managed on Fedora). Coarse RTD3
# avoids the fine-grained/self-refresh wake race with the dGPU's hardwired
# external-display outputs that's frozen the system. Doesn't reach idle D3cold in
# practice - gnome-shell/Mutter keeps the dGPU open for its whole session (native
# multi-GPU KMS enumeration, not EGL vendor priority; GNOME/mutter#2969) - but that's
# a separate, still-unresolved battery issue, not what this fix targets.
{...}: {
  environment.etc."modprobe.d/nvidia-power.conf".text = ''
    options nvidia NVreg_DynamicPowerManagement=1
  '';
}
