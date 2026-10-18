{ ... }: {
  programs.fastfetch = {
    enable = true;
    
    settings = {
      "\$schema" = "https://github.com";
      
      logo = {
        type = "auto";
        source = "~/Pictures/fastfetch/photo2.jpg";
        width = 40;
        height = 20;
      };

      display = {
        separator = " ❯ ";       
      };

      modules = [
        {
          type = "title";
          color = {
            user = "green";      
            at = "white";        
            host = "yellow";     
          };
        }
        
        { type = "custom"; format = ""; }

        # --- System Info ---
        { type = "os"; key = "os    "; keyColor = "green"; }
        { type = "kernel"; key = "kernel"; keyColor = "green"; }
        { type = "packages"; key = "pkgs  "; keyColor = "green"; }
        { type = "shell"; key = "shell "; keyColor = "green"; }
        { type = "uptime"; key = "uptime"; keyColor = "green"; }

        { type = "custom"; format = ""; }

        # --- Hardware Info ---
        { type = "cpu"; key = "cpu   "; keyColor = "yellow"; format = "{name}"; }
        { type = "gpu"; key = "gpu   "; keyColor = "yellow"; format = "{2}"; driverSpecific = true; }
        { type = "memory"; key = "memory"; keyColor = "yellow"; }
        { type = "board"; key = "board "; keyColor = "yellow"; }

        { type = "custom"; format = ""; }

        # --- Disks Info ---
        # Fixed the key names to be clean and explicitly padded to exactly 6 characters
        { type = "disk"; key = "/     "; keyColor = "white"; folders = [ "/" ]; }
        { type = "disk"; key = "SSD   "; keyColor = "white"; folders = [ "/home/vakh/SSD" ]; }
        { type = "disk"; key = "HDD   "; keyColor = "white"; folders = [ "/home/vakh/HDD" ]; }
        
        { type = "custom"; format = ""; }
        { type = "colors"; symbol = "circle"; }
      ];
    };
  };
}
