{
  description = "contextlm — package repository files into LLM context";

  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
    allow-import-from-derivation = true;
  };

  inputs = {
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      haskell-nix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ haskell-nix.overlay ];
          config = haskell-nix.config;
        };

        project = pkgs.haskell-nix.cabalProject' {
          src = ./.;
          compiler-nix-name = "ghc96";

          shell = {
            tools = {
              cabal = { };
              haskell-language-server = { };
              hlint = { };
            };
            buildInputs = [ pkgs.git ];
          };
        };

        flake = project.flake { };
      in
      flake
      // {
        packages.default = flake.packages."contextlm:exe:contextlm";
        devShells.default = flake.devShell;
      }
    );
}
