{
  description = "Searx plugin for Searching the Green Web";

  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "21.05";
  };

  outputs = { self, nixpkgs }:
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
          overlays = [ self.overlay ];
        });

      in {

        overlay = final: prev: rec {

          # TODO should this be in python packages?
          tgwf-green-results-searx-plugin = prev.python38Packages.buildPythonPackage {
            pname = "tgwf-searx-plugin";
            version = "0.2";
            buildInputs = [
              prev.searx
            ];
            src = ./.;
            doCheck = false;
          };

          python38 = let
            packageOverrides = python-self: python-super: {
              tgwf-green-results-searx-plugin = final.tgwf-green-results-searx-plugin;
            };
          in prev.python38.override {inherit packageOverrides;};

          searx = prev.searx.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
                tgwf-green-results-searx-plugin
              ];
              postFixup = ''
                ${oldAttrs.postFixup}
                mkdir -p $out/share/static/plugins/external_plugins/plugin_only_show_green_results
              '';
            });

        };

        packages = forAllSystems (system:
          {
            inherit (nixpkgsFor.${system}) tgwf-green-results-searx-plugin searx;
          }
        );

        # The default package for 'nix build'. This makes sense if the
        # flake provides only one package or there is a clear "main"
        # package.
        defaultPackage = forAllSystems (system: self.packages.${system}.searx);

  };

}
