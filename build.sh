#!/usr/bin/env bash
# =============================================================================
# build.sh - Cross-platform build script for 2CDT
# Targets: Windows x86/x64, Linux x86/x64/arm64, macOS x64/arm64
# Requires: Docker
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
SRC_DIR="${SCRIPT_DIR}/src"

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

# Create output dir
mkdir -p "${DIST_DIR}"

# =============================================================================
# Dockerfile inline - builds ALL targets in one container
# =============================================================================
DOCKERFILE=$(
	cat <<'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all cross-compilers and tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Native build
    gcc \
    # Windows cross-compilers
    mingw-w64 \
    # Linux ARM64 cross-compiler
    gcc-aarch64-linux-gnu \
    # Linux x86 (32-bit)
    gcc-multilib \
    # macOS cross-compiler (osxcross is complex, use zig cc instead)
    # Zig as universal cross-compiler for macOS targets
    wget \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (used for macOS cross-compilation)
RUN wget -q https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz \
    && tar -xf zig-linux-x86_64-0.13.0.tar.xz \
    && mv zig-linux-x86_64-0.13.0 /opt/zig \
    && ln -sf /opt/zig/zig /usr/local/bin/zig \
    && rm zig-linux-x86_64-0.13.0.tar.xz

WORKDIR /src
DOCKEREOF
)

# =============================================================================
# Build script that runs INSIDE the container
# =============================================================================
BUILD_SCRIPT=$(
	cat <<'BUILDEOF'
#!/bin/bash
set -euo pipefail

SRC="/src/src"
OUT="/out"
CFLAGS="-O3 -fsigned-char -DUNIX"
SOURCES="${SRC}/2cdt.c ${SRC}/tzxfile.c ${SRC}/getopt.c"

build() {
    local target="$1"
    local cc="$2"
    local out_file="$3"
    local extra_flags="${4:-}"

    echo "  -> Building ${out_file}..."
    mkdir -p "$(dirname "${OUT}/${out_file}")"

    if ${cc} ${CFLAGS} ${extra_flags} ${SOURCES} -o "${OUT}/${out_file}" 2>&1; then
        echo "     [OK] ${out_file}"
    else
        echo "     [FAIL] ${out_file}"
        return 1
    fi
}

echo ""
echo "=== Linux x86_64 ==="
build "linux-x64"   "gcc -m64"                 "linux/x86_64/2cdt"

echo ""
echo "=== Linux x86 (32-bit) ==="
build "linux-x86"   "gcc -m32"                 "linux/x86/2cdt"

echo ""
echo "=== Linux arm64 ==="
build "linux-arm64" "aarch64-linux-gnu-gcc"    "linux/arm64/2cdt"

echo ""
echo "=== Windows x64 ==="
build "win-x64"     "x86_64-w64-mingw32-gcc"   "windows/x86_64/2cdt.exe"    "-DWIN32 -UUNIX -Uunix"

echo ""
echo "=== Windows x86 (32-bit) ==="
build "win-x86"     "i686-w64-mingw32-gcc"     "windows/x86/2cdt.exe"       "-DWIN32 -UUNIX -Uunix"

echo ""
echo "=== macOS x86_64 ==="
build "macos-x64"   "zig cc -target x86_64-macos"  "macos/x86_64/2cdt"      "-Uunix -DUNIX"

echo ""
echo "=== macOS arm64 (Apple Silicon) ==="
build "macos-arm64" "zig cc -target aarch64-macos" "macos/arm64/2cdt"       "-Uunix -DUNIX"

echo ""
echo "=== Build complete ==="
ls -lR "${OUT}"
BUILDEOF
)

# =============================================================================
# Main build flow
# =============================================================================

IMAGE_NAME="2cdt-builder"

log "Building Docker image '${IMAGE_NAME}'..."
echo "${DOCKERFILE}" | docker build -t "${IMAGE_NAME}" - ||
	error "Failed to build Docker image"
ok "Docker image ready"

log "Running cross-compilation inside container..."
docker run --rm \
	-v "${SCRIPT_DIR}:/src:ro" \
	-v "${DIST_DIR}:/out" \
	"${IMAGE_NAME}" \
	bash -c "${BUILD_SCRIPT}"

ok "All targets built. Output in: ${DIST_DIR}/"
echo ""
echo "  Binaries:"
find "${DIST_DIR}" -type f | sort | while read -r f; do
	echo "    ${f#"${DIST_DIR}/"}"
done
