{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils}:
    flake-utils.lib.eachDefaultSystem (system:
      let
      pkgs = import nixpkgs {
        inherit system;
      };
  in {
    devShells.default = pkgs.mkShell {
      name = "telommeter";
      packages = with pkgs; [
        SDL2
        pkg-config
        zig
        zls
        compiledb
        gcc
      ];

      shellHook = ''
        exec zsh 
      '';
    };
  });
}