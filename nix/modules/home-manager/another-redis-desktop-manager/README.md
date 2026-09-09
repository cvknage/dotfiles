This module facilitates packaging of the Another Redis Desktop Manager's AppImage into NixOS.

How to update:
When a new update arrives, you need to run nix-prefetch-url to get the SHA of the file to update the module:

```
nix-prefetch-url https://github.com/qishibo/AnotherRedisDesktopManager/releases/download/v${version}/Another-Redis-Desktop-Manager-linux-${version}-x86_64.AppImage
```

Then update the section of the module with the current version number and SHA:

```
  # Set Version and SHA
  version = "1.7.1";
  SHA = "0m64isixgv6yx7h69x81nq97lx732dvvcdj1c7l9llp1qs7bir2y";
```

