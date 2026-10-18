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

        # --- Drop-out Wi-Fi Selection Menu ---
        "network" = {
          interface = "wlan0"; # Change this to your exact interface name if different
          format-wifi = "wifi {essid}";
          format-disconnected = "wifi none";
          tooltip-format = "{ifname} via {gwaddr}";
          # Toggles an interactive Fuzzel Wi-Fi connector menu when clicked
          on-click = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu";
        };

        # --- Drop-out Audio control Menu ---
        "pulseaudio" = {
          format = "vol {volume}%";
          format-muted = "vol mute";
          # Launches your choice of a clean mixer or device switcher
          on-click = "${pkgs.kitty}/bin/kitty --class pulsemixer -e pulsemixer";
          on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        "cpu" = { format = "cpu {usage}%"; };
        "memory" = { format = "mem {percentage}%"; };
        "battery" = { format = "bat {capacity}%"; };
        "tray" = { icon-size = 14; spacing = 10; };
      };
    };

    # Integrated Forest Green Theme Layer
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

      /* Distinct color keys matching your text fastfetch modules */
      #network {
        color: #a9b665; /* Leaf Green */
      }

      #pulseaudio {
        color: #e1e8e2; /* Soft White */
      }

      #cpu, #memory {
        color: #d8a657; /* Autumn Gold */
      }

      #clock, #battery, #window, #tray {
        padding: 0 12px;
        color: #e1e8e2;
      }
    '';
  };
}
