{ pkgs, ... }: {
  programs.fuzzel = {
    enable = true;
    
    settings = {
      main = {
        font = "Noto Sans:size=12";
        icon-theme = "Papirus-Dark";
        fields = "name,generic,comment,categories,filename";
        terminal = "${pkgs.kitty}/bin/kitty";
        prompt = "❯";             
        layer = "overlay";
        width = 40;
        horizontal-pad = 20;
        vertical-pad = 16;
        inner-pad = 10;
        line-height = 24;
      };

      colors = {
        background = "1a231eff";     
        text = "e1e8e2ff";           
        match = "a9b665ff";          
        selection = "2d3b32ff";      
        selection-text = "f4f7f4ff"; 
        selection-match = "d8a657ff";
        border = "879a72ff";     
      };

      border = {
        width = 2;
        radius = 12;
      };
    };
  };
}
