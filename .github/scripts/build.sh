#!/bin/bash
set -euo pipefail

# Usage: TARGET=x86_64-pc-windows-gnu ./generate-rustflags.sh

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

    # Populate /tmp/native-lib-pc with fake pkg-config files so we only dynamically link the things we want to
    rm -rf /tmp/native-lib-pc/
    mkdir -p /tmp/native-lib-pc/

    # Skip linker flags for mpv since we need more fine-grained control over it
    cat <<EOF >/tmp/native-lib-pc/mpv.pc
Name: mpv
Description: placeholder
Version: 999
Cflags: 
Libs: 
EOF

    cat <<EOF >/tmp/native-lib-pc/x11.pc
Name: X11
Description: placeholder
Version: 999
Cflags: 
Libs: -lX11
EOF

    cat <<EOF >/tmp/native-lib-pc/alsa.pc
Name: alsa
Description: placeholder
Version: 999
Cflags: 
Libs: -lasound
EOF

    #PKG_CONFIG_LIBDIR="/tmp/native-lib-pc/" \
    #PKG_CONFIG_PATH="/tmp/native-lib-pc/" \
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
