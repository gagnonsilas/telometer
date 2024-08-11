{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "imgui";
  buildInputs = with pkgs; [
    # libusb
    # SDL2
    glfw
    glfw-wayland
    pkg-config
    zig
    python311Packages.compiledb
    compdb
  ];
}
