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
        modules-right = [ "custom/wifi" "custom/volume" "memory" "cpu" "battery" "tray" ];

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
        "custom/wifi" = {
          exec = "${pkgs.networkmanager}/bin/nmcli -t -f ACTIVE,SSID dev wifi | ${pkgs.gnugrep}/bin/grep '^yes:' | ${pkgs.coreutils}/bin/cut -d ':' -f2 | ${pkgs.gawk}/bin/awk '{print \"wifi \" $0}' || echo \"wifi none\"";
          interval = 5;
          format = "{}";
          on-click = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu";
        };

        # --- AUDIO CONFIG ---
        "custom/volume" = {
          exec = "${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | ${pkgs.gawk}/bin/awk '{print \"vol \" $2*100 \"%\"}'";
          interval = 1;
          format = "{}";
          on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
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
        background-color: #1a231e; 
        color: #e1e8e2;                            
        border-bottom: 2px solid #879a72;          
      }

      #workspaces button {
        padding: 0 8px;
        color: #879a72;
        background-color: transparent;
      }

      #workspaces button.focused {
        color: #f4f7f4;
        background-color: #2d3b32;
        border-bottom: 2px solid #a9b665;
      }

      #custom-wifi { color: #a9b665; padding: 0 12px; }
      #custom-volume { color: #e1e8e2; padding: 0 12px; }
      #cpu, #memory { color: #d8a657; }
      #clock, #battery, #window, #tray { padding: 0 12px; color: #e1e8e2; }
    '';
  };
}
