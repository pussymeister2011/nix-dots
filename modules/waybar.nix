  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "network" "pulseaudio" "memory" "cpu" "battery" "tray" ];

        "network" = {
          interface = "wlan0";
          format-wifi = "wifi {essid}";
          format-disconnected = "wifi none";
          menu = "on-click";
          menu-file = "/home/vakh/.config/waybar/network_menu.xml";
          menu-actions = {
            "toggle" = "${pkgs.networkmanager}/bin/nmcli radio wifi toggle";
            "connections" = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu";
          };
        };

        "pulseaudio" = {
          format = "vol {volume}%";
          format-muted = "vol mute";
          menu = "on-click";
          menu-file = "/home/vakh/.config/waybar/audio_menu.xml";
          menu-actions = {
            "mute" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "mixer" = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          };
          on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+";
          on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05-";
        };
      };
    };

    style = ''
      menu {
        background-color: #1a231e !important;
        border: 2px solid #879a72 !important;
        border-radius: 6px !important;
        padding: 4px !important;
      }
    '';
  };
