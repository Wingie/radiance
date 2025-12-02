#!/bin/bash
set -euo pipefail
set -x

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

    # Populate /tmp/native-lib-pc with fake pkg-config files so we only dynamically link the things we want to
    rm -rf /tmp/native-lib-pc/
    mkdir -p /tmp/native-lib-pc/

    # Skip linker flags for mpv since we need more fine-grained control over it
#    cat <<EOF >/tmp/native-lib-pc/mpv.pc
#Name: mpv
#Description: placeholder
#Version: 999
#Cflags:
#Libs:
#EOF
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
