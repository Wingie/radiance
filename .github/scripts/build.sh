#!/bin/bash
set -euo pipefail

# Usage: TARGET=x86_64-pc-windows-gnu .github/scripts/build.sh

# Set linkers for cross-compilation targets using clang

case "$TARGET" in
    x86_64-unknown-linux-gnu)
        OS=LINUX
	EXE=radiance
	STRIP=strip
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="gcc"
	;;
    aarch64-unknown-linux-gnu)
        OS=LINUX
	EXE=radiance
	STRIP=aarch64-linux-gnu-strip
        export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="aarch64-linux-gnu-gcc"
	;;
    x86_64-pc-windows-gnu)
        OS=WINDOWS
	EXE=radiance.exe
	STRIP=x86_64-w64-mingw32-strip
	WINDRES=x86_64-w64-mingw32-windres
	;;
    x86_64-apple-darwin)
        OS=MACOS
	EXE=radiance
	STRIP=strip
	;;
    aarch64-apple-darwin)
        OS=MACOS
	EXE=radiance
	STRIP=strip
	;;
    *)
        echo "Unknown TARGET" >&2
	exit 1
	;;
esac

LIBMPV_STATIC_BUILD="$(cd "../libmpv-static-build" && pwd)"

# Set PKG_CONFIG_PATH based on target
export PKG_CONFIG_LIBDIR="${LIBMPV_STATIC_BUILD}/${TARGET}/output/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export PKG_CONFIG_ALLOW_CROSS=1

# Get all the static library dependencies
LIBS=$(pkg-config --static --libs mpv)

# Convert pkg-config output to RUSTFLAGS format
RUSTFLAGS=""

# Add all library flags, excluding -lpthread and -lstdc++ (we'll handle these separately)
for flag in $LIBS; do
  if [[ $flag == -l* ]] || [[ $flag == -L* ]]; then
    # Skip -lpthread and -lstdc++ since we'll link them statically
    if [[ $flag != "-lpthread" ]] && [[ $flag != "-lstdc++" ]]; then
      RUSTFLAGS="$RUSTFLAGS -C link-arg=$flag"
    fi
  fi
done

# Platform-specific linking
case "$OS" in
  WINDOWS)
    # Generate ICO file
    convert library/logo.png \
          \( -clone 0 -resize 16x16 \) \
          \( -clone 0 -resize 24x24 \) \
          \( -clone 0 -resize 32x32 \) \
          \( -clone 0 -resize 48x48 \) \
          \( -clone 0 -resize 256x256 \) \
          -delete 0 -alpha off -colors 256 /tmp/radiance_icon.ico

    cat <<EOF >/tmp/radiance_info.rc
0 ICON "/tmp/radiance_icon.ico"
1 VERSIONINFO
FILEVERSION     1,0,0,0
PRODUCTVERSION  1,0,0,0
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904E4"
    BEGIN
      VALUE "CompanyName", "Radiance"
      VALUE "FileDescription", "Video art software designed for live performance"
      VALUE "FileVersion", "1.0"
      VALUE "InternalName", "radiance"
      VALUE "OriginalFilename", "radiance.exe"
      VALUE "ProductName", "Radiance"
      VALUE "ProductVersion", "1.0"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x409, 1252
  END
END
EOF
    $WINDRES /tmp/radiance_info.rc /tmp/radiance_info.o

    RUSTFLAGS="$RUSTFLAGS -C link-arg=/tmp/radiance_info.o"

    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,--allow-multiple-definition"
    # Wrap all static libraries in a group to resolve circular dependencies
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bstatic"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,--start-group"
    # Force static linking of libgcc, libgcc_eh, libstdc++, libwinpthread, and libmingw32
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lmingw32"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lwinpthread"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lgcc_eh"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lgcc"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lstdc++"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,--end-group"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bdynamic"
    # MinGW runtime libraries (mingwex static, msvcrt uses system default CRT)
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,--start-group"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bstatic"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lmingwex"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bdynamic"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lmsvcrt"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,--end-group"
    # Windows system libraries (dynamically linked)
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lkernel32"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-ladvapi32"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lshell32"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lole32"
    ;;
  LINUX)
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bstatic"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lstdc++"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lgcc"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-Wl,-Bdynamic"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-lc"
    ;;
  MACOS)
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=Cocoa"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=IOKit"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=CoreFoundation"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=CoreVideo"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=CoreAudio"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=AudioToolbox"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=AVFoundation"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=OpenGL"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=CoreMedia"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=VideoToolbox"
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-framework -C link-arg=DiskArbitration"
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    exit 1
    ;;
esac

export RUSTFLAGS
echo "Generated RUSTFLAGS: $RUSTFLAGS"

cargo build --release --target "$TARGET"
$STRIP "target/${TARGET}/release/${EXE}"
