#!/usr/bin/env bash
# =============================================================================
# build.sh - Cross-platform build script for 2CDT
# Targets: Windows x86/x64, Linux x86/x64/arm64, macOS x64/arm64
# Requires: Docker
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[build]${NC} $*"; }
ok() { echo -e "${GREEN}[  ok ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn]${NC} $*"; }
error() {
	echo -e "${RED}[error]${NC} $*"
	exit 1
}

# Check Docker
command -v docker &>/dev/null || error "Docker is not installed or not in PATH"

mkdir -p "${DIST_DIR}"

# =============================================================================
# Dockerfile - uses Zig as universal cross-compiler for all targets
# Works on both x86_64 and arm64 hosts (Apple Silicon, etc.)
# =============================================================================
DOCKERFILE=$(
	cat <<'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + mingw for Windows targets + aarch64 cross-compiler
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    mingw-w64 \
    gcc-aarch64-linux-gnu \
    wget \
    xz-utils \
    ca-certificates \
    file \
    && rm -rf /var/lib/apt/lists/*

# Install Zig - detect host arch and download the right binary
# Zig is used for: Linux x86/x64, macOS x86_64/arm64 cross-compilation
RUN set -e; \
    ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then \
        ZIG_ARCH="x86_64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        ZIG_ARCH="aarch64"; \
    else \
        echo "Unsupported arch: $ARCH" && exit 1; \
    fi; \
    ZIG_VER="0.13.0"; \
    ZIG_TAR="zig-linux-${ZIG_ARCH}-${ZIG_VER}.tar.xz"; \
    wget -q "https://ziglang.org/download/${ZIG_VER}/${ZIG_TAR}" \
    && tar -xf "${ZIG_TAR}" \
    && mv "zig-linux-${ZIG_ARCH}-${ZIG_VER}" /opt/zig \
    && ln -sf /opt/zig/zig /usr/local/bin/zig \
    && rm "${ZIG_TAR}"

WORKDIR /src
DOCKEREOF
)

# =============================================================================
# Build script that runs INSIDE the container
# Uses Zig cc as a universal cross-compiler for most targets
# mingw-w64 for Windows (more reliable than zig for PE/COFF)
# =============================================================================
BUILD_SCRIPT=$(
	cat <<'BUILDEOF'
#!/bin/bash
set -euo pipefail

SRC="/src/src"
OUT="/out"
SOURCES="${SRC}/2cdt.c ${SRC}/tzxfile.c ${SRC}/getopt.c"

PASS=0
FAIL=0

build() {
    local label="$1"
    local out_file="$2"
    shift 2
    # remaining args are the full compiler invocation

    printf "  %-40s " "${label}..."
    mkdir -p "$(dirname "${OUT}/${out_file}")"

    if "$@" -O2 -fsigned-char ${SOURCES} -o "${OUT}/${out_file}" 2>/tmp/build_err; then
        echo "[OK]"
        PASS=$((PASS+1))
    else
        echo "[FAIL]"
        cat /tmp/build_err
        FAIL=$((FAIL+1))
    fi
}

echo ""
echo "=== Linux ==="
build "linux/x86_64" "linux/x86_64/2cdt" \
    zig cc -target x86_64-linux-gnu  -DUNIX

build "linux/x86" "linux/x86/2cdt" \
    zig cc -target x86-linux-gnu     -DUNIX

build "linux/arm64" "linux/arm64/2cdt" \
    zig cc -target aarch64-linux-gnu -DUNIX

echo ""
echo "=== Windows ==="
build "windows/x86_64" "windows/x86_64/2cdt.exe" \
    x86_64-w64-mingw32-gcc -DWIN32

build "windows/x86" "windows/x86/2cdt.exe" \
    i686-w64-mingw32-gcc   -DWIN32

echo ""
echo "=== macOS ==="
build "macos/x86_64" "macos/x86_64/2cdt" \
    zig cc -target x86_64-macos-none -DUNIX

build "macos/arm64" "macos/arm64/2cdt" \
    zig cc -target aarch64-macos-none -DUNIX

echo ""
echo "=== Summary: ${PASS} OK, ${FAIL} FAILED ==="

if [ ${FAIL} -gt 0 ]; then
    exit 1
fi

echo ""
echo "Binaries:"
find "${OUT}" -type f | sort | while read -r f; do
    SIZE=$(du -h "$f" | cut -f1)
    TYPE=$(file -b "$f" | cut -d, -f1)
    printf "  %-35s %6s  %s\n" "${f#"${OUT}/"}" "$SIZE" "$TYPE"
done
BUILDEOF
)

# =============================================================================
# Main
# =============================================================================

IMAGE_NAME="2cdt-builder"

log "Building Docker image '${IMAGE_NAME}' (first time may take a few minutes)..."
echo "${DOCKERFILE}" | docker build -t "${IMAGE_NAME}" - ||
	error "Failed to build Docker image"
ok "Docker image ready"

log "Running cross-compilation..."
docker run --rm \
	-v "${SCRIPT_DIR}:/src:ro" \
	-v "${DIST_DIR}:/out" \
	"${IMAGE_NAME}" \
	bash -c "${BUILD_SCRIPT}"

ok "Done. Output in: dist/"
