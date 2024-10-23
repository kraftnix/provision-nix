default:
  @just --list

sources: sources-nixos

# update nixos sources
sources-nixos:
  nvfetcher -c nixos/packages/sources.toml -o nixos/packages/_sources

# only works on a single host
# uses ssh ControlMaster to only use 1 SSH connection for deploy
deploy:
  DEPLOY_HOST=$1
  MODE=${2:-switch}
  ssh -M -N -f "deploy@$DEPLOY_HOST"
  colmena apply "$MODE" --on "$DEPLOY_HOST"
  ssh -O exit "deploy@$DEPLOY_HOST"
