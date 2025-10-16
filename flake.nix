{
  description = "Automerge Repo Sync Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      nixosModule = { config, pkgs, lib, ... }:
        with lib;
        let
          cfg = config.services.automerge-repo-sync-server;
        in {
          options.services.automerge-repo-sync-server = {
            enable = mkEnableOption "Automerge Repo Sync Server";

            port = mkOption {
              type = types.port;
              default = 3030;
              description = "Port to listen on for websocket connections";
            };

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/automerge-repo-sync-server";
              description = "Directory to store saved documents";
            };
          };

          config = mkIf cfg.enable {
            users.users.automerge-repo-sync-server = {
              isSystemUser = true;
              group = "automerge-repo-sync-server";
              home = cfg.dataDir;
            };
            users.groups.automerge-repo-sync-server = {};

            systemd.services.automerge-repo-sync-server = {
              description = "Automerge Repo Sync Server";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              environment = {
                PORT = toString cfg.port;
                DATA_DIR = cfg.dataDir;
                NODE_ENV = "production";
                NPM_CONFIG_CACHE = "${cfg.dataDir}/.npm";
              };

              serviceConfig = {
                Type = "simple";
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/automerge-repo-sync-server";
                WorkingDirectory = cfg.dataDir;
                Restart = "always";
                RestartSec = "5s";

                User = "automerge-repo-sync-server";
                Group = "automerge-repo-sync-server";

                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "full";
                ProtectHome = true;
                ReadWritePaths = [ cfg.dataDir ];
              };
            };

            systemd.tmpfiles.rules = [
              "d ${cfg.dataDir} 0755 automerge-repo-sync-server automerge-repo-sync-server -"
            ];
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        run-auto = pkgs.writeShellApplication {
          name = "automerge-repo-sync-server";
          runtimeInputs = [ pkgs.nodejs_20 ];
          text = ''
            set -euo pipefail
            WORK_DIR=$(mktemp -d)
            trap 'chmod -R u+w "$WORK_DIR" 2>/dev/null || true; rm -rf "$WORK_DIR"' EXIT

            echo "Using Node $(node --version)"
            echo "Using npm  $(npm --version)"

            echo "Copying source..."
            cp -r ${./.}/* "$WORK_DIR"/
            chmod -R u+w "$WORK_DIR"
            cd "$WORK_DIR"

            echo "Installing deps..."
            npm ci --omit=dev --no-audit --no-fund --prefer-offline --no-progress

            echo "Starting server..."
            exec node ./src/index.js "$@"
          '';
        };
      in
      {
        packages.default = run-auto;
        apps.default = {
          type = "app";
          program = "${run-auto}/bin/automerge-repo-sync-server";
        };
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            pnpm
            nodePackages.typescript
          ];
        };
      }
    ) // {
      nixosModules.default = nixosModule;
    };
}
