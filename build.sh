#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
build="$root/build"
lua="$root/vendor/lua-5.1.5/src"
mkdir -p "$build"
stage="$(mktemp -d "$build/.loopy.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/Loopy.app"
mkdir -p "$bundle/Contents/MacOS"

sources=("$root/src/LoopyMac.c")
for file in "$lua"/*.c; do
    case "${file##*/}" in
        lua.c|luac.c|print.c) continue ;;
    esac
    sources+=("$file")
done

xcrun --sdk macosx clang -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
    -std=gnu11 -Os -DLUA_USE_POSIX -Wno-deprecated-non-prototype \
    -I"$lua" -Wl,-headerpad,0x1000 "${sources[@]}" -o "$bundle/Contents/MacOS/Loopy"
cp "$root/Info.plist" "$bundle/Contents/Info.plist"
/usr/bin/ditto --norsrc --noextattr "$root/Resources" "$bundle/Contents/Resources"
xcrun lipo "$bundle/Contents/MacOS/Loopy" -verify_arch arm64 x86_64
/usr/bin/codesign --force --sign - --timestamp=none "$bundle"
/usr/bin/codesign --verify --strict "$bundle"

mkdir -p "$build/Loopy.app"
/usr/bin/rsync -a --checksum --delete-after "$bundle/" "$build/Loopy.app/"
/usr/bin/codesign --verify --strict "$build/Loopy.app"
printf 'Built %s\n' "$build/Loopy.app"
