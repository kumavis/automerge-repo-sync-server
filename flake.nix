{
  description = "Automerge Repo Sync Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Build and Run
        run-auto = pkgs.writeShellApplication {
          name = "automerge-repo-sync-server";
          runtimeInputs = [ pkgs.nodejs_20 ];
          text = ''
            set -euo pipefail
            WORK_DIR=$(mktemp -d)

            echo "Using Node $(node --version)"
            echo "Using npm  $(npm --version)"

            echo "Copying source to temporary directory..."
            cp -r ${./.}/* "$WORK_DIR"/
            chmod -R u+w "$WORK_DIR"
            cd "$WORK_DIR"

            echo "Installing dependencies with npm..."
            npm ci --omit=dev --no-write-lock-file

            echo "Starting server..."
            exec node ./src/index.js "$@"
          '';
        };

      in
      {
        # Systemd service module
        nixosModules.default = { config, pkgs, lib, ... }:
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
              systemd.services.automerge-repo-sync-server = {
                description = "Automerge Repo Sync Server";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];

                environment = {
                  PORT = toString cfg.port;
                  DATA_DIR = cfg.dataDir;
                  NODE_ENV = "production";
                };

                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${self.packages.${system}.default}/bin/automerge-repo-sync-server";
                  WorkingDirectory = cfg.dataDir;
                  Restart = "always";
                  RestartSec = "5s";

                  # Security hardening
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                  ProtectSystem = "full";
                  ProtectHome = true;
                  ReadWritePaths = [ cfg.dataDir ];
                };
              };

              # Create data directory
              systemd.tmpfiles.rules = [
                "d ${cfg.dataDir} 0755 root root -"
              ];
            };
          };

        packages.default = run-auto;

        apps.default = {
          type = "app";
          program = "${run-auto}/bin/automerge-repo-sync-server";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            nodePackages.npm
            pnpm
            nodePackages.prettier
            nodePackages.typescript
            nodePackages.typescript-language-server
          ];

          shellHook = ''
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Automerge Repo Sync Server - Development Environment"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "📦 Node.js: $(node --version)"
            echo "📦 npm:     $(npm --version)"
            echo "📦 pnpm:    $(pnpm --version)"
            echo ""
            echo "🚀 Quick Start (using npm like CI):"
            echo "   npm install     # Install dependencies"
            echo "   npm start       # Start the server"
            echo "   npm test        # Run tests"
            echo ""
            echo "Or use pnpm if you prefer:"
            echo "   pnpm install && pnpm start"
            echo ""
            echo "💡 Run with auto-install:"
            echo "   nix run         # Auto-installs deps and runs server"
            echo ""
          '';
        };
      }
    );
}
