{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # cimgui = {
      
    # };
  };
  outputs = { self, nixpkgs, flake-utils}:
    flake-utils.lib.eachDefaultSystem (system:
      let
      pkgs = import nixpkgs {
        inherit system;
      };
  in {
    dashboard = {header, main ? "./dashboard/main.zig"} : pkgs.stdenv.mkDerivation {
      name = "telometer-dashboard";
      src = builtins.path { name = "src"; path = ./.; };

      nativeBuildInputs = [ pkgs.zig.hook ];

      buildInputs = with pkgs; [
        SDL2
        pkg-config
        zig
      ];

      zigBuildFlags = [ "--build-file dashboard/build.zig" ];
      dontUseZigCheck = true;
    };

    devShells.default = pkgs.mkShell {
      name = "telometer";
      packages = with pkgs; [
        SDL2
        pkg-config
        zig
        zls
        compiledb
        (self.dashboard.x86_64-linux {header="../src/Example.h";})
      ];

      shellHook = ''
        exec zsh 
      '';
    };

  });
}