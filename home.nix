{ pkgs, ... }:

let
  llvm = pkgs.llvmPackages_18;

  # Wrapper that provides clang-18 with the correct resource-dir for wasm32 cross-compilation.
  # Nix splits clang-unwrapped headers into a separate .lib output, so the bare binary
  # can't find <stddef.h> etc. This wrapper wires the two together.
  wasm-clang = pkgs.writeShellScriptBin "wasm-clang" ''
    exec ${llvm.clang-unwrapped}/bin/clang-18 \
      -resource-dir=${llvm.clang-unwrapped.lib}/lib/clang/18 \
      "$@"
  '';
in
{
  imports = [
    ./home/theme.nix
    ./home/git.nix
    ./home/programs.nix
    ./home/secrets.nix
    ./home/shell.nix
    ./home/opencode.nix
    ./home/plannotator.nix
    ./home/glab.nix
    ./home/colima.nix
  ];

  home.stateVersion = "25.11";

  # ── Packages (CLI tools managed by nix instead of brew) ─────────────────────
  home.packages = with pkgs; [
    actionlint
    asdf-vm
    bazelisk
    biome
    btop
    bun
    coreutils
    colima
    lima-additional-guestagents
    delta
    difftastic
    docker-client
    docker-buildx
    docker-compose
    docker-credential-helpers
    fastfetch
    fd
    git-filter-repo
    gawk
    glab
    gnupg
    jq
    just
    nerd-fonts.fira-code
    nginx
    opencode
    openjdk
    ripgrep
    shellcheck
    tesseract
    tenv
    tmux
    util-linux
    uv
    vault
    watch
    websocat
    zig

    # rust
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt

    # cloudflare workers (rust → wasm32)
    worker-build
    wasm-bindgen-cli
    binaryen # provides wasm-opt
    lld # provides wasm-ld linker for wasm32 targets
    wasm-clang # clang-18 with resource-dir wired for wasm32 cross-compilation
  ];

}
