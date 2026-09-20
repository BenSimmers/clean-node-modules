#!/bin/sh
set -eu

REPO="BenSimmers/clean-node-modules"
BIN="clean-node-modules"
VERSION="${VERSION:-latest}"
PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"

die() { printf 'install: %s\n' "$1" >&2; exit 1; }

if [ -n "${BASE_URL:-}" ]; then
  base="$BASE_URL"
elif [ "$VERSION" = latest ]; then
  base="https://github.com/$REPO/releases/latest/download"
else
  base="https://github.com/$REPO/releases/download/$VERSION"
fi

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  die "need curl or wget"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

printf 'downloading %s (%s) ...\n' "$BIN" "$VERSION"
fetch "$base/$BIN" "$tmp/$BIN" \
  || die "could not download $base/$BIN -- is there a published release?"

if fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" 2>/dev/null; then
  if command -v sha256sum >/dev/null 2>&1; then
    sum="$(sha256sum "$tmp/$BIN" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    sum="$(shasum -a 256 "$tmp/$BIN" | awk '{print $1}')"
  else
    sum=""
  fi
  if [ -n "$sum" ]; then
    want="$(awk -v f="$BIN" '$2 == f || $2 == "*" f {print $1; exit}' "$tmp/SHA256SUMS")"
    [ -n "$want" ] || die "no checksum for $BIN in SHA256SUMS"
    [ "$sum" = "$want" ] || die "checksum mismatch: got $sum, want $want"
    echo "checksum ok"
  else
    echo "warning: no sha256sum/shasum available, skipping verification" >&2
  fi
else
  echo "warning: no SHA256SUMS in the release, skipping verification" >&2
fi

mkdir -p "$BINDIR"
install -m 0755 "$tmp/$BIN" "$BINDIR/$BIN" 2>/dev/null \
  || { cp "$tmp/$BIN" "$BINDIR/$BIN" && chmod 0755 "$BINDIR/$BIN"; } \
  || die "could not write $BINDIR/$BIN"

printf 'installed %s\n' "$("$BINDIR/$BIN" --version) -> $BINDIR/$BIN"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf '\n%s is not on your PATH. Add it with:\n\n  export PATH="%s:$PATH"\n' \
       "$BINDIR" "$BINDIR" ;;
esac
