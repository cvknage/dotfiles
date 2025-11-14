{pkgs, ...}: let
  commonHardening = {
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
      commonHardening
      // {
        Type = "oneshot";
        ExecStart = [
          "/run/current-system/sw/bin/chgrp uinput /dev/uinput"
          "/run/current-system/sw/bin/chmod 0660 /dev/uinput"
        ];
        RemainAfterExit = true;
        ReadWritePaths = ["/dev/uinput"]; # only /dev/uinput is writable
        CapabilityBoundingSet = ["CAP_CHOWN" "CAP_FOWNER"]; # allow only chown/chmod
        SystemCallFilter = ["@system-service" "@file-system" "@chown"]; # allow basic service, file, and chown syscalls
      };
  };

  systemd.services.kanata = {
    description = "Kanata keyboard remapper";
    wantedBy = ["multi-user.target"];
    requires = ["dev-uinput.device"];
    after = ["dev-uinput.device" "uinput-perms.service"];
    wants = ["uinput-perms.service"];
    serviceConfig =
      commonHardening
      // {
        Type = "notify";
        ExecStart = ''${pkgs.kanata}/bin/kanata --cfg ${./kanata_us.kbd}'';
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
      };
  };
}
/*
# This works, but it modefies "services.kanata" too much for my liking
{...}: {
  hardware.uinput.enable = true; # enable uinput kernel driver
  boot.kernelModules = ["uinput"]; # load uinput on boot
  users.groups.uinput = {}; # create dedicated 'uinput' group

  # trigger fix service when /dev/uinput appears
  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="systemd", ENV{SYSTEMD_WANTS}="uinput-perms.service"
  '';

  # set permissions for /dev/uinput
  systemd.services."uinput-perms" = {
    description = "Set /dev/uinput to 0660 root:uinput";
    serviceConfig = {
      Type = "oneshot"; # run once
      ExecStart = [
        # correct owner and mode
        "/run/current-system/sw/bin/chgrp uinput /dev/uinput"
        "/run/current-system/sw/bin/chmod 0660 /dev/uinput"
      ];
      RemainAfterExit = true; # keep marked as active after run
    };
  };

  systemd.services."kanata-all" = {
    requires = ["dev-uinput.device"]; # depend on /dev/uinput
    after = ["dev-uinput.device" "uinput-perms.service"]; # start after perms fixed
    wants = ["uinput-perms.service"]; # start fix service if needed
    serviceConfig = {
      # PrivateUsers = lib.mkForce false; # disable UID/GID remap
      # SupplementaryGroups = ["uinput"]; # allow access to /dev/uinput
      DevicePolicy = "closed"; # deny all devices except allowlist
      DeviceAllow = ["/dev/uinput rw" "char-input r"]; # minimal access
      Restart = "on-failure"; # retry if race at boot
      RestartSec = "500ms"; # short delay before retry
      StartLimitBurst = 10; # max retries
      StartLimitIntervalSec = 30; # retry window
      ConditionPathIsWritable = "/dev/uinput"; # only start if /dev/uinput is ready
    };
  };

  services.kanata = {
    enable = true;
    keyboards.all.configFile = ./kanata_us.kbd;
  };
}
*/
/*
# This works, but it modefies permissions on the the 'input' group which is problematic
{...}: {
  boot.kernelModules = ["uinput"];
  hardware.uinput.enable = true;

  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
  '';

  systemd.services."kanata-all".serviceConfig = {
    SupplementaryGroups = ["input"];
  };

  services.kanata = {
    enable = true;
    keyboards.all.configFile = ./kanata_us.kbd;
  };
}
*/
/*
# This used to work, but now Kanata fails to start due to permission issues
{...}: {
  # Enable the uinput module
  boot.kernelModules = ["uinput"];

  # Enable uinput
  hardware.uinput.enable = true;

  # Set up udev rules for uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
  '';

  # Ensure the uinput group exists
  users.groups.uinput = {};

  # Add the Kanata service user to necessary groups
  systemd.services.kanata-internalKeyboard.serviceConfig = {
    SupplementaryGroups = [
      "input"
      "uinput"
    ];
  };

  # Enable Kanata service with config file
  services.kanata = {
    enable = true;
    keyboards = {
      all = {
        configFile = ./kanata_us.kbd;
      };
    };
  };
}
*/

