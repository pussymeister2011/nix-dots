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

        "network" = {
          interface = "wlan0"; 
          format-wifi = "wifi {essid}";
          format-disconnected = "wifi none";
          on-click = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu";
        };

        # --- Premium GUI Application Audio Hub ---
        "pulseaudio" = {
          format = "vol {volume}%";
          format-muted = "vol mute";
          # Launches the fluid GTK4 app-by-app layout mixer on left click
          on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          # Mutes globally on right click
          on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        "cpu" = { format = "cpu {usage}%"; };
        "memory" = { format = "mem {percentage}%"; };
        "battery" = { format = "bat {capacity}%"; };
        "tray" = { icon-size = 14; spacing = 10; };
      };
    };

    # Forest Green Styling Rules Layer
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
      
      /* Highlights your new interactive Volume block to indicate a GUI action */
      #pulseaudio { 
        color: #e1e8e2; 
        padding: 0 12px;
      }
      #pulseaudio:hover {
        background-color: #2d3b32;
        color: #a9b665; /* Transitions to leaf green on mouse hover */
      }

      #cpu, #memory { color: #d8a657; }
      #clock, #battery, #window, #tray { padding: 0 12px; color: #e1e8e2; }
    '';
  };
}
