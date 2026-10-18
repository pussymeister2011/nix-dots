# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  xdg.portal.config.common.default = "*";

  ##BOOT
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  ##NETWORKING

  networking.hostName = "vakh";

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";
  
  ##SERVICES

  # services.printing.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
  services.displayManager.sessionPackages = [ pkgs.niri ];
  services.displayManager.sddm = {
    enable = true;
    theme = "pixie";            
    wayland.enable = true;      
    package = pkgs.kdePackages.sddm; 
    extraPackages = [
      pkgs.kdePackages.qtsvg
      pkgs.kdePackages.qtdeclarative
      pkgs.kdePackages.qt5compat
    ];
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.udisks2.enable = true;

  services.gvfs.enable = true;

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk  
    ];
  };

  services.upower.enable = true;

  ##USERS & PACKAGES
  services.libinput.enable = true;

  users.users.vakh = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
    
  environment.systemPackages = with pkgs; [
    micro
    wget
    git
    (inputs.pixie-sddm.packages.${pkgs.stdenv.hostPlatform.system}.pixie-sddm.override {
      background = "/home/vakh/Pictures/wallpaper.jpg"; 
      autoColor = false;    
      backgroundColor = "#1a231e";
      accentColor = "#a9b665";    
      textColor = "#e1e8e2";      
      fontFamily = "JetBrains Mono";
    })
    pulsemixer
    networkmanager_dmenu
    xwayland
    xwayland-satellite
    pavucontrol
    brightnessctl
  ];


  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
  ];

  networking.firewall.enable = false;

  xdg.menus.enable = true;
  xdg.mime.enable = true;
  services.dbus.enable = true;
  environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  nix.settings.auto-optimise-store = true;

  nix.settings.experimental-features = [ "nix-command " "flakes" ];
###############################################
  # system.copySystemConfiguration = true;

  system.stateVersion = "26.05"; 

}

