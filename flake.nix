{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
      in
      with builtins;
      rec {

        package_dir = pkgs.callPackage ./dashboard/deps.nix { zig = zig; };

        # packages.default;
        source = pkgs.stdenv.mkDerivation rec {
          type = "app";
          name = "telometer-src";
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
            PACKAGE_DIR=${package_dir}
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath buildInputs}
            zig build --global-cache-dir $(pwd)/.cache --cache-dir $(pwd)/.zig-cache --system $PACKAGE_DIR -Dcpu=baseline --prefix $out

            cd ..

            mkdir -p $out/lib
  
            g++ -fPIC -o cpp/telometer.o -c cpp/TelometerImpl.cpp -Icpp -Isrc
            g++ -shared -o $out/lib/telometer.so cpp/telometer.o -Icpp -Isrc

            cp cpp/*.h $out/include
            cp src/Telometer.h $out/include
            
            cp -r . $out/src
          '';

          env = {
            # NIX_CFLAGS_COMPILE = ''
            #   -I$out/src/cpp"
            # '';
          };

        };

        telometer-build =
          {
            header,
            backend,
            main ? "test",
          }:
          pkgs.stdenv.mkDerivation {
            name = "telometer";
            srcs = [
              source
            ];
            sourceRoot = source.name;

            nativeBuildInputs = with pkgs; [ zig.hook ];

            buildInputs = with pkgs; [
              SDL2
              xorg.libX11
              pkg-config
              zlib
            ];

            dontInstall = true;

            buildPhase = ''
              cp ${header} src/src/Packets.h
              cp ${backend} src/dashboard/backend.zig
              cd src/dashboard
              PACKAGE_DIR=${pkgs.callPackage dashboard/deps.nix { zig = zig; }}
              zig build --global-cache-dir $(pwd)/.cache --cache-dir $(pwd)/.zig-cache --system $PACKAGE_DIR -Dcpu=baseline --prefix $out
            '';
            # cat ${header}
          };
        packages.default = source;

        devShells.default = pkgs.mkShell {
          name = "telometer";
          packages = with pkgs; [
            SDL2
            pkg-config
            source
            zig
            zls
            compiledb
          ];

          shellHook = ''
            exec zsh 
          '';
        };
      }
    );
}
