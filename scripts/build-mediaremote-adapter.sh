#!/bin/zsh
# Compila MediaRemoteAdapter (https://github.com/ungive/mediaremote-adapter, BSD-3)
# y deja en Freesla/Resources/MediaRemoteAdapter/ lo que la app necesita:
#   - MediaRemoteAdapter.framework.zip  (el framework comprimido; ver nota)
#   - mediaremote-adapter.pl            (script que se ejecuta con /usr/bin/perl)
#   - MediaRemoteAdapter-LICENSE.txt
#
# Nota: el framework va en .zip a propósito. Si se deja suelto dentro de la carpeta
# sincronizada de Xcode, Xcode lo detecta como librería y lo ENLAZA dentro de Freesla,
# que es justo lo que no queremos: solo debe cargarlo perl. La app lo descomprime al arrancar.
#
# Uso: ./scripts/build-mediaremote-adapter.sh
set -euo pipefail

COMMIT="2ef957c736256cee7905c9f3f1c7e279087bf195"
ROOT="${0:A:h:h}"
DEST="$ROOT/Freesla/Resources/MediaRemoteAdapter"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --quiet https://github.com/ungive/mediaremote-adapter.git "$WORK/src"
git -C "$WORK/src" checkout --quiet "$COMMIT"
SRC="$WORK/src"

# Las fuentes del framework, tal cual las lista su CMakeLists.txt.
FILES=($(grep -A20 'set(ADAPTER_SOURCES' "$SRC/CMakeLists.txt" | grep -oE 'src/[a-zA-Z_/]+\.m' | sed "s#^#$SRC/#"))

FW="$WORK/out/MediaRemoteAdapter.framework"
mkdir -p "$FW"
xcrun clang -dynamiclib -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
  -fobjc-arc -fvisibility=default \
  -I"$SRC/include" -I"$SRC/src" "${FILES[@]}" \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter \
  -o "$FW/MediaRemoteAdapter"
codesign --force --sign - "$FW/MediaRemoteAdapter"

mkdir -p "$DEST"
rm -f "$DEST/MediaRemoteAdapter.framework.zip"
/usr/bin/ditto -c -k --keepParent "$FW" "$DEST/MediaRemoteAdapter.framework.zip"
cp "$SRC/bin/mediaremote-adapter.pl" "$DEST/mediaremote-adapter.pl"
cp "$SRC/LICENSE" "$DEST/MediaRemoteAdapter-LICENSE.txt"
echo "OK -> $DEST"
