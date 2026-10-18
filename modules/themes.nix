{ pkgs, ... }: {
  # 1. Force Universal GTK (2, 3, and 4) to prefer Dark Theme
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # 2. Force QT (5 and 6) apps like Dolphin to match GTK parameters
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  # 3. Handle modern portal handshakes (Fixes apps using libadwaita)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "org.kde.dolphin.desktop" ];
    };
  };
  xdg.desktopEntries = {
    "org.kde.dolphin" = {
      name = "Dolphin";
      exec = "dolphin %u";
      mimeType = [ "inode/directory" ];
    };
  };

}
