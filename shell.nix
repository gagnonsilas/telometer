{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "imgui";
  buildInputs = with pkgs; [
    # libusb
    SDL2
    pkg-config
    python311Packages.compiledb
    compdb
    neocmakelsp

    expect
    # for Gattlib
    readline
    bluez
    glib
    #python311Packages.libbluetooth-dev
    #python311Packages.libreadline-dev
  ];
}
