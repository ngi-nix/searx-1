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

      in {

        packages.x86_64-linux.testPlugin = nixpkgs.legacyPackages.x86_64-linux.python38Packages.buildPythonPackage rec {
          pname = "tgwf-searx-plugin";
          version = "0.2";

          buildInputs = [
            nixpkgsFor."x86_64-linux".searx
          ];

          src = ./.;

          doCheck = false;
        };

        # patchedSearx
        out1 = with nixpkgsFor."x86_64-linux";
          let
            my-python-packages = python-packages: with python-packages; [
              self.packages.x86_64-linux.testPlugin
            ];
            python-with-my-packages = python3.withPackages my-python-packages;
            searx-with-python = searx.override {
              python3 = python-with-my-packages;
            };
            searx-with-python-and-env = searx-with-python.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
                self.outputs.packages.x86_64-linux.testPlugin
              ];
              postFixup = ''
                ${oldAttrs.postFixup}
                mkdir -p $out/share/static/plugins/external_plugins/plugin_only_show_green_results
              '';
            });
          in searx-with-python-and-env;


  };

}
