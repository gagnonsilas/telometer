{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # zig2nix.url = "github:Cloudef/zig2nix";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        # env = zig2nix.outputs.zig-env.${system} {};

      in
      with builtins;
      rec {
        # packages.default;
        dashboard = pkgs.stdenv.mkDerivation rec {
          type = "app";
          name = "telometer-dashboard-src";
          # src = cleanSource ./.;
          src = ./.;
          # sourceRoot = ./dashboard;

          nativeBuildInputs = with pkgs; [ zig.hook ];

          buildInputs = with pkgs; [
            SDL2
            xorg.libX11
            pkg-config
            zlib
          ];

          # dontConfigure = true;
          dontInstall = true;
          buildPhase = ''
            NO_COLOR=1 # prevent escape codes from messing up the `nix log`
            cd dashboard
            PACKAGE_DIR=${pkgs.callPackage ./dashboard/deps.nix { zig = zig; }}
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath buildInputs}
            zig build --global-cache-dir $(pwd)/.cache --cache-dir $(pwd)/.zig-cache --system $PACKAGE_DIR -Dcpu=baseline --prefix $out

            cp -r ../ $out/src
          '';

        };

        devShells.default = pkgs.mkShell {
          name = "telometer";
          packages = with pkgs; [
            SDL2
            pkg-config
            zig
            zls
            compiledb
            self.dashboard.x86_64-linux
            # (telometer-test{header="./src/Example.h";})
            # env.pkgs.zon2nix
          ];

          shellHook = ''
            exec zsh 
          '';
        };

        apps.telometer = (self.test.x86_64-linux { header = "../src/Example.h"; });

        apps.default = apps.telometer.system;
      }
    );
}
