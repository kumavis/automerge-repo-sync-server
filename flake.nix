{
  description = "Automerge repo sync server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.default = pkgs.buildNpmPackage {
          pname = "@automerge/automerge-repo-sync-server";
          version = "0.3.0";
          src = ./.;
          npmDepsHash = "sha256-mZRQb/TjRR8K8ZKKALuDNQZLmJ6G2T9+UgHY9+t6zYo=";
          dontNpmBuild = true;

          # https://docs.npmjs.com/cli/v10/commands/npm-ci?v=true#omit
          npmInstallFlags = [ "--omit=dev" ];
        };

        nixosModules.default = { config, lib, pkgs, ... }: {
          options.services.automerge-repo-sync-server = {
            enable = lib.mkEnableOption "Automerge repo sync server";
            port = lib.mkOption {
              type = lib.types.port;
              default = 3030;
            };
            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = "Extra environment variables for the Automerge repo sync server.";
            };
          };

          config = lib.mkIf config.services.automerge-repo-sync-server.enable {
            systemd.services.automerge-repo-sync-server = {
              description = "Automerge repo sync server";
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Restart = "always";
                User = "automerge";
                Environment = lib.flatten ([
                  "PORT=${toString config.services.automerge-repo-sync-server.port}"
                ] ++ lib.mapAttrsToList (n: v: "${n}=${v}") config.services.automerge-repo-sync-server.environment);
              };
            };
          };
        };
      });
}
