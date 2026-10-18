{ pkgs, ... }: {
  programs.firefox = {
    enable = true;

    profiles.vakh = {
      id = 0;
      isDefault = true;
      name = "vakh";

      # Enforce legacy stylesheet customization flags to allow custom themes
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Allows custom userChrome CSS
        "browser.uidensity" = 1;                                      # Compact UI mode
        "browser.compactmode.show" = true;                            # Reveals the compact layout toggle
        "privacy.trackingprotection.enabled" = true;                  # Native privacy protection active
      };

      # Custom CSS inject matching your Niri and Fuzzel layouts
      userChrome = ''
        /* --- Root Theme Variables Matching Your Forest Scheme --- */
        :root {
          --arrowpanel-background: #1a231eff !important;      /* Deep Pine Menu Background */
          --arrowpanel-color: #e1e8e2ff !important;           /* Soft White-Green Tint Text */
          --arrowpanel-border-color: #879a72ff !important;    /* Sage Green Borders */
          
          --toolbar-field-background-color: #2d3b32ff !important; /* Lighter Muted Forest input fields */
          --toolbar-field-color: #f4f7f4ff !important;
          --toolbar-field-focus-background-color: #1a231eff !important;
        }

        /* --- Browser Background and Tab Color Schemes --- */
        #navigator-toolbox {
          background-color: #1a231eff !important;             /* Deep Pine base frame */
          border-bottom: 2px solid #879a72ff !important;      /* Sage Green boundary line */
        }

        /* --- Selected/Active Tab Styling --- */
        .tab-background[selected="true"] {
          background-color: #2d3b32ff !important;             /* Match Fuzzel selected line */
          background-image: none !important;
          border-top: 2px solid #a9b665ff !important;         /* Highlight Leaf Green accent border */
        }

        .tab-label[selected="true"] {
          color: #f4f7f4ff !important;                        /* Bright Text on highlighted tab */
        }

        /* --- Inactive Tab Styling --- */
        .tab-background:not([selected="true"]) {
          background-color: transparent !important;
        }

        .tab-label:not([selected="true"]) {
          color: #879a72ff !important;                        /* Muted Sage text for silent tabs */
        }

        /* --- URL Bar/Search Bar Containers --- */
        #urlbar-background {
          background-color: #2d3b32ff !important;
          border: 1px solid #879a72ff !important;
          border-radius: 6px !important;
        }

        #urlbar[focused="true"] #urlbar-background {
          border: 1px solid #a9b665ff !important;             /* Glows leaf green when typing */
        }
      '';
    };
  };
}
