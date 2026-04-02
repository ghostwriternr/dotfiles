{ config, lib, pkgs, ... }:

# Declarative Colima configuration.
#
# Colima expects to write to its config file on startup, so we can't
# use a read-only nix store symlink. Instead we use an activation
# script that copies a mutable version of the file into place whenever
# the nix-managed source changes.
#
# After changing this file: nix-rebuild && colima stop && colima start
# If you change an immutable setting (arch, vmType, runtime, mountType):
#   colima delete && colima start

let
  username = "naresh";

  colimaYaml = pkgs.writeText "colima.yaml" ''
    # ── Resources ──────────────────────────────────────────────────────────
    # Internal guidance: half your CPUs, quarter your RAM.
    # M3 Pro: 11 cores, 36 GB → 6 CPUs, 8 GiB.
    cpu: 6
    memory: 8
    disk: 100

    # ── VM identity (immutable after creation) ─────────────────────────────
    arch: aarch64
    runtime: docker
    vmType: vz
    mountType: virtiofs

    # ── Emulation ──────────────────────────────────────────────────────────
    # Rosetta for fast amd64 emulation (requires vmType: vz on Apple Silicon)
    rosetta: true
    binfmt: true

    # ── Networking ─────────────────────────────────────────────────────────
    hostname: colima
    network:
      address: false
      mode: shared
      interface: en0
      preferredRoute: false
      dns: null
      dnsHosts: {}
      hostAddresses: false
      gatewayAddress: 192.168.5.2

    # ── Port forwarding ────────────────────────────────────────────────────
    portForwarder: ssh
    forwardAgent: true

    # ── Mounts ─────────────────────────────────────────────────────────────
    # Empty list = Colima default ($HOME mounted writable).
    # Do NOT set to null -- that disables the default mount.
    mounts: []

    mountInotify: true

    # ── Docker daemon ──────────────────────────────────────────────────────
    docker: {}

    # ── Provisioning ───────────────────────────────────────────────────────
    # Injects Cloudflare Zero Trust cert into the VM's CA store on every
    # startup so Docker builds work with WARP enabled.
    provision:
      - mode: system
        script: |
          CERT_PATH="/usr/local/share/ca-certificates/cloudflare_zero_trust.crt"
          [ -f "$CERT_PATH" ] && [ -s "$CERT_PATH" ] && exit 0
          HOST_CERT="/Users/${username}/.config/cloudflare/zero_trust_cert.pem"
          if [ -f "$HOST_CERT" ]; then
            cp "$HOST_CERT" "$CERT_PATH"
            update-ca-certificates
          fi

    # ── Kubernetes (disabled) ──────────────────────────────────────────────
    kubernetes:
      enabled: false
      version: v1.35.0+k3s1
      k3sArgs:
        - --disable=traefik
      port: 0

    # ── Misc ───────────────────────────────────────────────────────────────
    autoActivate: true
    nestedVirtualization: false
    sshConfig: true
    sshPort: 0
    cpuType: ""
    diskImage: ""
    rootDisk: 20
    modelRunner: ""
    env: {}
  '';
in
{
  # Copy (not symlink) so Colima can write to the file at startup.
  # On each activation, overwrite with the nix-managed version.
  home.activation.colimaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install -Dm644 ${colimaYaml} "$HOME/.colima/default/colima.yaml"
  '';
}
