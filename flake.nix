{
  description = "CLIPS game.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nil = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nil, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
    devShells.x86_64-linux = {
      default = pkgs.mkShell {
        packages = with pkgs; [
          clips

          # Both of these used with VSCode.
          nixpkgs-fmt
          nil.packages.${system}.default
        ];
      };
    };
  };
}