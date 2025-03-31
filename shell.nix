{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "imgui";
  buildInputs = with pkgs; with python312Packages; [
    # libusb
    SDL2
    dbus.dev
    pkg-config
    zig
    zls
    compiledb
    gcc
  ];
}
