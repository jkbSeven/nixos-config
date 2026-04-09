{ config, pkgs, ... }:

{
  imports = [
    ./modules/hyprland.nix
  ];
  home.username = "jkb";
  home.homeDirectory = "/home/jkb";

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    zsh
    git
    bat
    tmux
    fzf
    jq
    fd
    ripgrep

    # obsidian - fails to run as expects opengl drivers in the Nix-used /run/opengl_..., but they are installed with pacman
    nerd-fonts.ubuntu-mono

    brightnessctl
  ];

  home.file."${config.xdg.configHome}/tmux/tmux.conf".source = ./dotfiles/tmux.conf;

  home.file.".local/bin" = {
    source = ./dotfiles/bin;
    recursive = true;
  };

  programs.zsh = {
    enable = true;

    setOptions = [
      "vi" # vim motions in the terminal
    ];

    shellAliases = {
      hm = "home-manager switch --flake ~/.config/home-manager#jkb";
      gs = "git status";
      l = "ls -la";
      vim = "nvim";
      vpn-conn = "sudo wg-quick up wg0"; # requires wg0.conf in /etc/wireguard/
      vpn-dc = "sudo wg-quick down wg0";
    };

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.zsh.oh-my-zsh = {
    enable = true;
    plugins = [ "git" ];
    theme = "robbyrussell";
  };

  programs.git = {
    enable = true;
    settings.user.name = "jkbSeven";
    settings.user.email = "Jacob202@protonmail.com";
  };

  programs.alacritty = {
    enable = true;
    #package = null;

    settings = {
      font = {
        normal = {
          family = "UbuntuMono Nerd Font";
          style = "Regular";
        };
        size = 16;
      };
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "UbuntuMono Nerd Font";
      size = 16;
    };
  };

  programs.neovim = {
    enable = true;

    # extraLuaPackages = ps: [ ps.magick ];

    extraPackages = with pkgs; [
      imagemagick
      lua-language-server
      pyright
    ];
  };

  programs.wofi.enable = true;
}
