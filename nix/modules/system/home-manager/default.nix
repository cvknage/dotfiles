{...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    sharedModules = [
      ../../../homes/shared
    ];
  };
}
