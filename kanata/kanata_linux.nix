# Hardened systemd definitions shared by the NixOS and System Manager kanata setups.
{pkgs}: rec {
  # Permissions for /dev/uinput. `static_node` also applies them when the
  # uinput module loads after udev has started. `TAG+="systemd"` is needed or
  # `dev-uinput.device` never activates and `kanata.service` times out on it.
  uinputUdevRule = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", TAG+="systemd", OPTIONS+="static_node=uinput"
  '';

  sharedHardening = {
    NoNewPrivileges = true; # forbid gaining privileges
    PrivateTmp = true; # isolate /tmp
    ProtectSystem = "strict"; # RO system dirs
    ProtectHome = true; # hide /home
    ProtectHostname = true; # protect hostname
    ProtectControlGroups = true; # protect cgroups
    ProtectKernelModules = true; # block module ops
    ProtectKernelLogs = true; # protect dmesg
    ProtectKernelTunables = true; # block /proc/sys writes
    ProtectClock = true; # block clock changes
    RestrictSUIDSGID = true; # ignore setuid/setgid
    RestrictRealtime = true; # no RT priority
    RestrictNamespaces = true; # no new namespaces
    PrivateNetwork = true; # no network
    LockPersonality = true; # forbid changing ABI personality
    MemoryDenyWriteExecute = true; # block W+X mappings
    ProcSubset = "pid"; # hide non-self processes
    ProtectProc = "invisible"; # hide other /proc
    IPAddressDeny = ["any"]; # deny IP access
    RestrictAddressFamilies = ["AF_UNIX"]; # local sockets only
    SystemCallArchitectures = ["native"]; # native arch only
    UMask = "0077"; # strict default perms
  };

  kanataService = {
    description = "Kanata keyboard remapper";
    wantedBy = ["multi-user.target"];
    requires = ["dev-uinput.device"];
    after = ["dev-uinput.device"];
    serviceConfig =
      {
        Type = "notify";
        ExecStart = ''${pkgs.kanata}/bin/kanata --cfg ${./kanata_us.kbd}'';

        # Hardening
        DynamicUser = true; # ephemeral user for FS isolation
        PrivateUsers = true; # isolate user IDs in namespace
        RuntimeDirectory = "kanata"; # tmp runtime dir
        SupplementaryGroups = ["uinput" "input"]; # inject-only access
        DevicePolicy = "closed"; # deny all devices by default
        DeviceAllow = ["/dev/uinput rw" "char-input r"]; # allow uinput + read raw input
        SystemCallFilter = ["@system-service" "~@privileged" "~@resources"]; # allow normal syscalls, block privileged/resource ones
        CapabilityBoundingSet = [""]; # drop all Linux capabilities
        Restart = "on-failure"; # retry on early race
        RestartSec = "500ms"; # small backoff
        StartLimitBurst = 10; # retry budget
        StartLimitIntervalSec = 30; # retry window
        ConditionPathIsWritable = "/dev/uinput"; # start only when ready
      }
      // sharedHardening;
  };
}
