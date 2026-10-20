{ pkgs, ... }:

let
  # shows a notification whenever the keyboard layout changes
  layoutNotify = pkgs.writeShellApplication {
    name = "layout-notify";
    runtimeInputs = [ pkgs.jq pkgs.libnotify ];
    text = ''
      niri msg --json event-stream | while read -r line; do
        if echo "$line" | jq -e 'has("KeyboardLayoutSwitched")' >/dev/null; then
          name=$(niri msg --json keyboard-layouts | jq -r '.names[.current_idx]')
          notify-send -t 1500 -h string:x-canonical-private-synchronous:layout "Layout" "$name"
        fi
      done
    '';
  };
in
{
  # volume / brightness popup
  services.swayosd.enable = true;
  xdg.configFile."swayosd/style.css".text = ''
    window#osd {
      padding: 12px 20px;
      border-radius: 16px;
      border: 1px solid rgba(127, 176, 105, 0.25);
      background: rgba(10, 24, 17, 0.92);
    }

    window#osd #container {
      margin: 14px;
    }

    window#osd image {
      color: #7fb069;
    }

    window#osd label {
      color: #cfe8d5;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-weight: bold;
    }

    window#osd progressbar:disabled,
    window#osd image:disabled {
      opacity: 0.5;
    }

    window#osd progressbar {
      min-height: 6px;
      border-radius: 999px;
      background: transparent;
      border: none;
    }

    window#osd trough {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: rgba(31, 61, 43, 0.9);
    }

    window#osd progress {
      min-height: inherit;
      border-radius: inherit;
      border: none;
      background: #7fb069;
    }
  '';


  # notification daemon, green to match the bar
  services.mako = {
    enable = true;
    settings = {
      background-color = "#0a1811eb";
      text-color = "#cfe8d5";
      border-color = "#7fb06940";
      border-radius = 12;
      border-size = 1;
      padding = "10";
      default-timeout = 2500;
    };
  };

  home.packages = [ layoutNotify ];
}
