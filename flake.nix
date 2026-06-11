{
	description = "solitaire for the web";
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	inputs.flake-utils.url = "github:numtide/flake-utils";

	outputs = { self, nixpkgs, flake-utils }:
		flake-utils.lib.eachDefaultSystem (system:
			let pkgs = nixpkgs.legacyPackages.${system};
			in {
				packages.solitaire = pkgs.stdenv.mkDerivation {
					name = "solitaire";
					src = self;
					buildPhase = "odin run karl2d/build_web -- . -o:size";
					installPhase = "cp -r bin/web $out";

					buildInputs = [ pkgs.odin ];
				};

				defaultPackage = self.packages.${system}.solitaire;
				devShells.default = pkgs.mkShell { packages = [ pkgs.odin ]; };
		});
}
