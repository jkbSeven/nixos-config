{ config, pkgs, ... }:

{
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

    neovim
    fd # for neovim plugins
    ripgrep # for neovim plugins
    tree-sitter # for neovim

    # obsidian - fails to run as expects opengl drivers in the Nix-used /run/opengl_..., but they are installed with pacman
    nerd-fonts.ubuntu-mono
  ];

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

  programs.wofi.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    systemd.enable = false;

    settings = {
      "$mod" = "SUPER";

      "$terminal" = "alacritty";
      "$fileManager" = "dolphin";
      "$menu" = "wofi";

      monitor = [
        "DP-3, highrr, auto, 1" # use `hyprctl monitors` to find the display ID
        ", preferred, auto, 1" # for ad-hoc monitors, preferred resolution, placed on the right side of main monitor
      ];

      bind = [
        "$mod, Q, killactive"
        "$mod, T, exec, $terminal"
        "$mod, F, exec, $fileManager"
        "$mod, W, exec, firefox"
        "$mod, D, exec, wofi --show run"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (
          builtins.genList (
            i:
            let
              ws = i + 1;
            in
            [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          ) 9
        )
      );

      exec-once = [
        "waybar"
      ];

      animation = [
        "workspaces, 0"
        "windows, 1, 1, default"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 1;
      };

      input = {
        accel_profile = "flat";
        # force_no_accel = true; # not recommended in Hyprland docs
        sensitivity = 0;
      };

    };
  };

  programs.waybar = {
    enable = true;
    settings.main = {
      height = 30;
      spacing = 4;

      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "wireplumber" ];

      clock = {
        format = "{:%H:%M, %F}";
        tooltip-format = "<tt><small>{calendar}</small></tt>"; # needed to display calendar

        timezone = "Europe/Warsaw";

        calendar = {
          mode = "month";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            months = "<span color='#ffead3'><b>{}</b></span>";
            days = "<span color='#ecc6d9'><b>{}</b></span>";
            weeks = "<span color='#99ffdd'><b>W{}</b></span>";
            weekdays = "<span color='#ffcc66'><b>{}</b></span>";
            today = "<span color='#ff6699'><b><u>{}</u></b></span>";
          };
        };

        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_down";
          on-scroll-down = "shift_up";
        };
      };

      wireplumber = {
        format = "Vol: {volume}% (mic: {format_source})";
        format-muted = "Vol: muted (mic: {format_source})";
        format-source = "{volume}%";
        format-source-muted = "muted";

        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      };

    };
  };
}
