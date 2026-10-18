{ pkgs, ... }: {
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

        "niri/workspaces" = {
          format = "{index}";
        };

        "niri/window" = {
          format = "❯ {title}";
          max-length = 40;
        };

        "clock" = {
          format = "{:%H:%M · %b %d}";
        };

        # --- NETWORK CONFIG ---
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

        # --- AUDIO CONFIG ---
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

        "cpu" = { format = "cpu {usage}%"; };
        "memory" = { format = "mem {percentage}%"; };
        "battery" = { format = "bat {capacity}%"; };
        "tray" = { icon-size = 14; spacing = 10; };
      };
    };

    # --- BAR STYLE SHEET ---
    style = ''
      * {
        font-family: "Noto Sans", sans-serif;
        font-size: 13px;
        font-weight: bold;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: rgba(26, 35, 30, 0.75); 
        color: #e1e8e2;                            
        border-bottom: 2px solid #879a72;          
      }

      #workspaces button {
        padding: 0 8px;
        color: #879a72;
      }

      #workspaces button.focused {
        color: #f4f7f4;
        background-color: #2d3b32;
        border-bottom: 2px solid #a9b665;
      }

      #network { color: #a9b665; }
      #pulseaudio { color: #e1e8e2; }
      #cpu, #memory { color: #d8a657; }
      #clock, #battery, #window, #tray { padding: 0 12px; color: #e1e8e2; }

      menu {
        background-color: #1a231e !important;
        border: 2px solid #879a72 !important;
        border-radius: 6px !important;
        padding: 6px !important;
      }
      menuitem {
        color: #e1e8e2 !important;
        padding: 4px 12px !important;
      }
      menuitem:hover {
        background-color: #2d3b32 !important;
        color: #a9b665 !important;
      }
    '';
  };

  # --- XML DROPDOWN GENERATORS ---
  xdg.configFile."waybar/network_menu.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <menu id="menu">
        <item>
          <attribute name="label">Toggle Wi-Fi Power</attribute>
          <attribute name="action">toggle</attribute>
        </item>
        <item>
          <attribute name="label">Select Wi-Fi Networks (Fuzzel)</attribute>
          <attribute name="action">connections</attribute>
        </item>
      </menu>
    </interface>
  '';

  xdg.configFile."waybar/audio_menu.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <menu id="menu">
        <item>
          <attribute name="label">Toggle Mute State</attribute>
          <attribute name="action">mute</attribute>
        </item>
        <item>
          <attribute name="label">Open Advanced Mix Panel (GUI)</attribute>
          <attribute name="action">mixer</attribute>
        </item>
      </menu>
    </interface>
  '';
}
