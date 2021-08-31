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

        # To use as `nix develop`
        # will provide shell with
        # - `searx-run`
        # - python with installed plugin module
        # - simple searx config that would allow its launch & plugin utilization
        devShell = forAllSystems (system: nixpkgsFor.${system}.mkShell rec {
          packages = with nixpkgsFor.${system}; [ searx tgwf-green-results-searx-plugin ];
          settingsFile = nixpkgsFor.${system}.writeText "settings.yml"
            ''
            use_default_settings: True
            server:
                secret_key : "dev-server-secret"

            plugins:
              - only_show_green_results
            '';
          SEARX_SETTINGS_PATH = "${settingsFile}";
        });

        nixosModules.tgwf-green-results-searx-plugin-module = { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];
          services.searx.settings = {
            plugins = [ "only_show_green_results" ];
          };
        };

  };

}
