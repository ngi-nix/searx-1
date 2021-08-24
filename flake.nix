{
description = "Tracking The Trackers - API to submit APKs for testing.";

  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "21.05";
  };

  inputs.machnix = {
    type = "github";
    owner = "DavHau";
    repo = "mach-nix";
    ref = "3.1.1";
  };

  outputs = { self, nixpkgs, machnix }:
    let

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          # overlays = [ self.overlay ];
        });

      # mach-nix instantiated for supported system types.
      machnixFor = forAllSystems (system:
        import machnix {
          pkgs = (nixpkgsFor.${system}).pkgs;
          python = "python38";

          # Pin pypi repo to a specific commit which includes all necessary
          # Python deps. The default version is updated with every mach-nix
          # release might be be sufficient for newer releases.
          # The corresponding sha256 hash can be obtained with:
          # $ nix-prefetch-url --unpack https://github.com/DavHau/pypi-deps-db/tarball/<pypiDataRev>
          pypiDataRev = "c86b4490a7d838bd54a2d82730455e96c6e4eb14";
          pypiDataSha256 =
            "0al490gi0qda1nkb9289z2msgpc633rv5hn3w5qihkl1rh88dmjd";
        });
      in {

        packages.x86_64-linux.cleanSearx = nixpkgs.legacyPackages.x86_64-linux.searx;

        packages.x86_64-linux.testSearx = nixpkgs.legacyPackages.x86_64-linux.searx.overrideAttrs (oldAttrs: {
          propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
            # self.outputs.packages.x86_64-linux.testPlugin
          ];
        });

        out1 = with nixpkgsFor."x86_64-linux";
          let
            my-python-packages = python-packages: with python-packages; [
              # self.packages.x86_64-linux.testPlugin
              # other python packages you want
            ];
            python-with-my-packages = python3.withPackages my-python-packages;
          # in pkgs.searx.override {
          in nixpkgs.legacyPackages.x86_64-linux.searx.override {
            python3 = python-with-my-packages;
          };

        packages.x86_64-linux.testPlugin = nixpkgs.legacyPackages.x86_64-linux.python38Packages.buildPythonPackage rec {
          pname = "tgwf-searx-plugin";
          version = "0.2";

          buildInputs = [
            nixpkgsFor."x86_64-linux".searx
          ];

          src = ./.;

          doCheck = false;
        };

        # Provide a nix-shell env to work with vulnerablecode.
        devShell = forAllSystems (system:
          with nixpkgsFor.${system};
          mkShell {
            # will be available as env var in `nix develop` / `nix-shell`.
            # VULNERABLECODE_INSTALL_DIR = vulnerablecode;
            yo = "hello";
            buildInputs = [
              searx
              self.outputs.packages.x86_64-linux.testPlugin
            ];
            # shellHook = ''
            #   alias vulnerablecode-manage.py=${vulnerablecode}/manage.py
            # '';
          });

  };

}
