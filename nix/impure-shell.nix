pkgs:
pkgs.mkShell {
  name = "mina-impure-shell";
  buildInputs = with pkgs; [
    opam
    pkg-config
    gnum4
    jemalloc
    gmp
    libffi
    openssl.dev
    postgresql.out
    sodium-static.out
    sodium-static.dev
    go
    capnproto
    zlib.dev
    bzip2.dev
    ncurses
    crypto-rust-toolchain.rust
  ];
  OPAMSWITCH = "mina";
  shellHook = ''
    eval $(opam env)
    if ! opam list --installed 2>&1 | grep mina 2>&1 > /dev/null; then
      printf "=== Welcome to Mina! ===\n"
      printf "You are currently in a shell with all native libraries present.\n"
      printf "To get all OCaml dependencies, run:\n"
      echo
      tput bold
      printf 'opam init --bare\n'
      printf 'opam switch import src/opam.export\n'
      printf 'eval $(opam env)\n'
      printf './scripts/pin-external-packages.sh\n'
      tput sgr0
      echo
      printf "After that, you can build Mina using:\n"
      echo
      tput bold
      printf "make build\n"
      tput sgr0
      echo
      printf "This message will go away once you set up your OCaml dependencies.\n"
    fi
  '';
}
