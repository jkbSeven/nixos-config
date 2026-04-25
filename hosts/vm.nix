{ config, pkgs, hostname, lib, ... }:

{
    imports = [
        ../modules/proxmox-vm.nix
    ];

    system.stateVersion = "25.11";

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    nixpkgs.config.allowUnfree = true;



    boot.loader.systemd-boot.enable = true;

    networking.hostName = hostname;

    time.timeZone = "Europe/Warsaw";
    i18n.defaultLocale = "en_US.UTF-8";

    services.openssh.enable = true;

    users.users.jkb = {
        isNormalUser = true;
        extraGroups = [
            "wheel"
        ];
        shell = pkgs.zsh;
        packages = with pkgs; [ ];
        openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGUyXopT6n4AgbFY4E2Xgf753xESReel5p45qDYIRaV"
        ];
    };

    programs.zsh.enable = true;

    environment.systemPackages = with pkgs; [
        bat
        vim
        git
    ];

}
