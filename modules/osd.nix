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
