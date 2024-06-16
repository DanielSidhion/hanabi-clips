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

    clips-with-pc = pkgs.clips.overrideAttrs (final: previous: {
      installPhase = ''
        ${previous.installPhase}

        mkdir -p $out/lib/pkgconfig
        cat >> $out/lib/pkgconfig/clips.pc <<EOF
        Name: clips
        Description: CLIPS
        Version: 6.4.1
        Cflags: -I$out/include
        Libs: -L$out/lib -lclips
        EOF
      '';

      meta.pkgConfigModules = [ "clips" ];
    });
  in
  {
    devShells.x86_64-linux = {
      default = pkgs.mkShell {
        packages = with pkgs; [
          clips-with-pc

          cargo
          rustc
          rust-analyzer
          rustfmt
          pkg-config
          libclang.lib

          # Both of these used with VSCode.
          nixpkgs-fmt
          nil.packages.${system}.default
        ];

        env = {
          RUST_BACKTRACE = "full";
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
        };
      };
    };
  };
}