{ ... }: {
  programs.waybar = {
    enable = true;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;
        
        # Clean minimalist layout spacing
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "memory" "cpu" "battery" "tray" ];

        "niri/workspaces" = {
          format = "{index}"; # Minimal numerical layout matching text style
        };

        "niri/window" = {
          format = "❯ {title}"; # Utilizes your preferred prompt arrow
          max-length = 40;
        };

        "clock" = {
          format = "{:%H:%M · %b %d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };


        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "󰁹 {capacity}%";
          format-charging = "󰂄 {capacity}%   ";
        };

        "tray" = {
          icon-size = 14;
          spacing = 10;
        };
      };
    };

    # Forest Green Styling Layer
    style = ''
      * {
        font-family: "Noto Sans", "Helvetica Neue", sans-serif;
        font-size: 13px;
        font-weight: bold;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: rgba(26, 35, 30, 0.75); /* 75% transparent deep pine moss */
        color: #e1e8e2;                            /* Soft white-green tint text */
        border-bottom: 2px solid #879a72;          /* Sage green border outline */
        transition-property: background-color;
        transition-duration: .5s;
      }

      /* Workspaces styling */
      #workspaces button {
        padding: 0 8px;
        color: #879a72; /* Inactive tabs match sage border */
        background-color: transparent;
      }

      #workspaces button.focused {
        color: #f4f7f4;
        background-color: #2d3b32; /* Highlighted row matches Fuzzel active row */
        border-bottom: 2px solid #a9b665; /* Leaf Green accent indicator */
      }

      #workspaces button.urgent {
        color: #d8a657; /* Autumn gold notification flag */
      }

      /* Modules block styling */
      #clock,
      #cpu,
      #memory,
      #battery,
      #window,
      #tray {
        padding: 0 12px;
        color: #e1e8e2;
      }

      /* Hardware specifics mirroring Fastfetch key color groupings */
      #cpu, #memory {
        color: #d8a657; /* Autumn Gold */
      }

      #battery.critical:not(.charging) {
        color: #f38ba8;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
    '';
  };
}
