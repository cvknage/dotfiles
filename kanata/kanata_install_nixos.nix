{pkgs, ...}: let
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
in {
  hardware.uinput.enable = true;
  boot.kernelModules = ["uinput"];
  users.groups.uinput = {};

  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="systemd", ENV{SYSTEMD_WANTS}="uinput-perms.service"
  '';

  systemd.services.uinput-perms = {
    description = "Set /dev/uinput to 0660 root:uinput";
    serviceConfig =
      {
        Type = "oneshot";
        ExecStart = [
          "/run/current-system/sw/bin/chgrp uinput /dev/uinput"
          "/run/current-system/sw/bin/chmod 0660 /dev/uinput"
        ];
        RemainAfterExit = true;

        # Hardening
        ReadWritePaths = ["/dev/uinput"]; # only /dev/uinput is writable
        CapabilityBoundingSet = ["CAP_CHOWN" "CAP_FOWNER"]; # allow only chown/chmod
        SystemCallFilter = ["@system-service" "@file-system" "@chown"]; # allow basic service, file, and chown syscalls
      }
      // sharedHardening;
  };

  systemd.services.kanata = {
    description = "Kanata keyboard remapper";
    wantedBy = ["multi-user.target"];
    requires = ["dev-uinput.device"];
    after = ["dev-uinput.device" "uinput-perms.service"];
    wants = ["uinput-perms.service"];
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
