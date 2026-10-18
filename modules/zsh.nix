{ pkgs, ... }: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "nicoulaj"; 
      plugins = [ "git" "sudo" "colored-man-pages" "extract" "history" "systemd" "command-not-found" ];
    };

    initContent = ''
      fastfetch
    '';
    
    shellAliases = {
      update = "sudo nixos-rebuild switch --recreate-lock-file --flake path:/home/YOUR_USERNAME/nix#YOUR_HOSTNAME";
      rebuild = "sudo nixos-rebuild switch --flake ~/nix#vakh";
    };
  };
}
