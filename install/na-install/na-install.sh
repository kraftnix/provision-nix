#!/usr/bin/env bash

LUKS_KEY_LENGTH=${1:-128}

# check env vars present
if [[ -z "${NA_HOST}" ]]; then
  echo "NA_HOST env variable missing."
  exit 1
fi
if [[ -z "${NA_ROOT_SSH}" ]]; then
  echo "NA_ROOT_SSH env variable missing."
  exit 1
fi

# Build up array of arguments...
args=()

# generate LUKS key
if [[ -n "${NA_LUKS_PROVISION}" ]]; then
  echo "Encrypting with luks key length: $LUKS_KEY_LENGTH"
  # see if user sets password
  if [[ -n "${NA_LUKS_PASSWORD}" ]]; then
    read -p "Enter your password: " -s LUKS_PASSWORD
    echo $LUKS_PASSWORD > /tmp/root-luks.key
  else
    echo "Encrypting with luks key length: $LUKS_KEY_LENGTH"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $LUKS_KEY_LENGTH | head -n 1 | tr -d '\n' > /tmp/root-luks.key
  fi
  args+=( '--disk-encryption-keys' '/tmp/root-luks.key' '/tmp/root-luks.key' )
fi

# generate a private/public key pair
if [[ -n "${NA_INITRD_PROVISION}" ]]; then
  echo "Provisioning initrd keys"
  # Create a temporary directory
  temp=$(mktemp -d)

  # Function to cleanup temporary directory on exit
  cleanup() {
    rm -rf "$temp"
  }
  trap cleanup EXIT

  # Create the directory where sshd expects to find the host keys
  install -d -m755 "$temp/etc/initrd"

  ssh-keygen -t ed25519 -N "" -C "initrd-root-ssh" -f "$temp/etc/initrd/ssh_host_ed25519_key"
  args+=( '--extra-files' "$temp" )
fi

args+=( '--flake' ".#$NA_HOST" $NA_ROOT_SSH )

# Install NixOS to the host system with our secrets
echo "Running nixos-anywhere"
nixos-anywhere "${args[@]}"
