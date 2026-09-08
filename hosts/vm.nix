{
  config,
  pkgs,
  lib,
  ...
}:

{
  system.stateVersion = "25.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  services.qemuGuest.enable = true;

  virtualisation.diskSize = 8192; # in MiB

  image.modules.proxmox = {
    proxmox.qemuConf = {
      cores = 4;
      memory = 4096; # in MiB
    };
    proxmox.cloudInit.enable = false;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  networking.useDHCP = true;

  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.zsh;
    packages = [ ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGUyXopT6n4AgbFY4E2Xgf753xESReel5p45qDYIRaV"
    ];
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [ git ];
}
