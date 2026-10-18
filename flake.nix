{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};	
		pixie-sddm.url = "github:xCaptaiN09/pixie-sddm"; 
		astal = {
		  url = "github:aylur/astal";
		  inputs.nixpkgs.follows = "nixpkgs";
		};
		ags = {
		  url = "github:aylur/ags";
		  inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, home-manager, pixie-sddm, ... }@inputs: {
		nixosConfigurations.vakh = nixpkgs.lib.nixosSystem {
			system = "x86_64-linux";
			specialArgs = { inherit inputs; };
			modules = [
				./configuration.nix
				./hardware-configuration.nix
				home-manager.nixosModules.home-manager
				{
					home-manager.useGlobalPkgs = true;
					home-manager.useUserPackages = true;
					home-manager.extraSpecialArgs = { inherit inputs; };
					home-manager.users.vakh = import ./home.nix;
				}
			];
		};
	};
}
