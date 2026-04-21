{
  description = "ZMK config dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zmk-nix.url = "path:/mnt/storage/projects/zmk-nix";
  };

  outputs = {
    self,
    nixpkgs,
    zmk-nix,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = zmk-nix.mkShell {
      inherit system nixpkgs;
      extraPackages = [pkgs.keymap-drawer];
      extraShellHook = ''
        export PATH="$(pwd)/bin:$PATH"
      '';
    };
  };
}
