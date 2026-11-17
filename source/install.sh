#!/bin/sh
# Build frames from this checkout and install it onto this machine.
#
#   sh source/install.sh
#   sh source/install.sh --prefix "$HOME/.local/bin"
#
# The tool reads its built in presets from `Frames_FramesCommand.bundle` in its own directory, so both go to the
# prefix together.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE="$ROOT/source/frames"
PREFIX=${FRAMES_PREFIX:-/usr/local/bin}
BUNDLE=Frames_FramesCommand.bundle

while [ $# -gt 0 ]; do
  case $1 in
    --prefix) PREFIX=${2:?--prefix needs a directory}; shift 2 ;;
    --prefix=*) PREFIX=${1#--prefix=}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v swift >/dev/null 2>&1 || { echo "swift is required." >&2; exit 1; }

mkdir -p "$PREFIX" 2>/dev/null || true
if [ ! -w "$PREFIX" ]; then
  echo "$PREFIX is not writable. Rerun with sudo, or pass --prefix \"\$HOME/.local/bin\"." >&2
  exit 1
fi

swift build -c release --package-path "$PACKAGE"
BUILT=$(swift build -c release --package-path "$PACKAGE" --show-bin-path)

# The bundle is replaced whole, so a preset removed from frames does not stay behind from an older install.
rm -rf "${PREFIX:?}/$BUNDLE"
cp -R "$BUILT/$BUNDLE" "$PREFIX/$BUNDLE"
install -m 0755 "$BUILT/frames" "$PREFIX/frames"

echo "installed  $PREFIX/frames"
"$PREFIX/frames" --version

case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) echo; echo "$PREFIX is not on PATH. Add it to use 'frames' by name." ;;
esac
