{pkgs, ...}:

{
  programs.git = {
    enable = true;
    ignores = [
      # macOS
      ## General
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"

      ## Thumbnails
      "._*"

      ## Files that might appear in the root of a volume
      ".DocumentRevisions-V100"
      ".fseventsd"
      ".Spotlight-V100"
      ".TemporaryItems"
      ".Trashes"
      ".VolumeIcon.icns"
      ".com.apple.timemachine.donotpresent"

      ## Directories potentially created on remote AFP share
      ".AppleDB"
      ".AppleDesktop"
      "Network Trash Folder"
      "Temporary Items"
      ".apdisk"

      # Gnu/Linux
      "*~"

      ## temporary files which can be created if a process still has a handle open of a deleted file
      ".fuse_hidden*"

      ## KDE directory preferences
      ".directory"

      ## Linux trash folder which might appear on any partition or disk
      ".Trash-*"

      ## .nfs files are created when an open file is removed but is still being accessed
      ".nfs*"

      # Windows
      ## Windows thumbnail cache files
      "Thumbs.db"
      "Thumbs.db:encryptable"
      "ehthumbs.db"
      "ehthumbs_vista.db"

      ## Dump file
      "*.stackdump"

      ## Folder config file
      "[Dd]esktop.ini"

      ## Recycle Bin used on file shares
      "$RECYCLE.BIN/"

      ## Windows Installer files
      "*.cab"
      "*.msi"
      "*.msix"
      "*.msm"
      "*.msp"

      ## Windows shortcuts
      "*.lnk"

      # Vim Sessions
      "Session.vim"
    ];
  };
}
