{ pkgs, ... }:

{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;

    settings = {
      # background: blurred, darkened screenshot of what was on screen
      screenshots = true;
      effect-blur = "12x6";
      effect-vignette = "0.5:0.6";
      fade-in = 0.2;
      color = "0a1811"; # fallback if the screenshot fails

      # clock inside the ring
      clock = true;
      timestr = "%H:%M";
      datestr = "%A, %d %B";
      font = "JetBrainsMono Nerd Font";
      font-size = 26;

      # ring
      indicator = true;
      indicator-idle-visible = true;
      indicator-radius = 120;
      indicator-thickness = 8;
      indicator-caps-lock = true;
      ignore-empty-password = true;
      show-failed-attempts = true;

      # idle
      inside-color = "0a1811d9";
      ring-color = "7fb069";
      line-color = "00000000";
      separator-color = "00000000";
      text-color = "cfe8d5";

      # typing
      key-hl-color = "a3c585";
      bs-hl-color = "c9524a";

      # checking the password
      inside-ver-color = "0a1811d9";
      ring-ver-color = "a3c585";
      line-ver-color = "00000000";
      text-ver-color = "cfe8d5";

      # wrong password
      inside-wrong-color = "0a1811d9";
      ring-wrong-color = "c9524a";
      line-wrong-color = "00000000";
      text-wrong-color = "c9524a";

      # cleared input
      inside-clear-color = "0a1811d9";
      ring-clear-color = "d9a441";
      line-clear-color = "00000000";
      text-clear-color = "d9a441";

      # caps lock
      inside-caps-lock-color = "0a1811d9";
      ring-caps-lock-color = "d9a441";
      line-caps-lock-color = "00000000";
      text-caps-lock-color = "d9a441";
      caps-lock-key-hl-color = "d9a441";
      caps-lock-bs-hl-color = "c9524a";
    };
  };
}
