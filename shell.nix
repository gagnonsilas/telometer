{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "imgui";
  buildInputs = with pkgs; [
    # libusb
    SDL2
    pkg-config
    python311Packages.compiledb
  ];
}
