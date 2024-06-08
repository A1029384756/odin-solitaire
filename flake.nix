{
  description = "Odin Devshell";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        nativeBuildInputs = with pkgs; [ 
          xorg.libX11
          glfw
          libGL
          #put your env dependencies here
        ];
        buildInputs = with pkgs; [
          odin
          ols
          gdb
          #put your runtime and build dependencies here
        ];
      in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = nativeBuildInputs ++ buildInputs;
          LD_LIBRARY_PATH = "${lib.makeLibraryPath nativeBuildInputs}";
        };
      }
    );
}
