{
  description = "C++ dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              ninja
              gcc
              gdb
              clang-tools  # clangd, clang-format, clang-tidy
            ];
            # nixpkgs sets _FORTIFY_SOURCE=2 which warns (and -Werror's) on
            # debug builds without -O. Disable so cpp-init's strict warnings
            # don't break Debug configs.
            hardeningDisable = [ "fortify" ];
          };
        });
    };
}
