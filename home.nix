{ config, pkgs, ... }: {
	home.username = "vakh";
	home.homeDirectory = "/home/vakh";
	home.stateVersion = "26.05";

	home.packages = with pkgs; [
		kdePackages.dolphin                  
		kdePackages.kdegraphics-thumbnailers 
		kdePackages.ffmpegthumbs             
		kdePackages.kio-extras
		dconf
		telegram-desktop
		swaybg
		pulseaudio
		nerd-fonts.jetbrains-mono
	];
	
	programs.kitty = {
	  enable = true;
	  settings = {
	    confirm_os_window_close = 0;
		shell = "${pkgs.zsh}/bin/zsh";			    
		background_opacity = "0.4"; 
	  };
	};

	xdg.mimeApps = {
  		enable = true;
  		defaultApplications = {
    		"inode/directory" = [ "org.kde.dolphin.desktop" ];
  		};
	};
	dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
     };
    };

	
	imports = [
    	    ./modules # Nix looks inside this folder and automatically runs default.nix
	];					
	programs.home-manager.enable = true;
}
