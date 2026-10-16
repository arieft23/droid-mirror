#!/usr/bin/env bash
# ==============================================================================
# DroidMirror One-Line Installer for macOS
# Usage:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/arieft23/droid-mirror/main/install.sh)"
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "  ____             _     _ __  __ _                     "
echo " |  _ \ _ __ ___ (_) __| |  \/  (_)_ __ _ __ ___  _ __  "
echo " | | | | '__/ _ \| |/ _\` | |\/| | | '__| '__/ _ \| '__| "
echo " | |_| | | | (_) | | (_| | |  | | | |  | | | (_) | |    "
echo " |____/|_|  \___/|_|\__,_|_|  |_|_|_|  |_|  \___/|_|    "
echo -e "${NC}"
echo -e "${BOLD}📱 Scrcpy & ADB Desktop Wrapper for macOS${NC}"
echo -e "--------------------------------------------------------"

# 1. Verify macOS
OS="$(uname -s)"
if [ "$OS" != "Darwin" ]; then
    echo -e "${RED}❌ Error: DroidMirror khusus dibuat untuk sistem operasi macOS.${NC}"
    exit 1
fi

# 2. Check Architecture
ARCH="$(uname -m)"
echo -e "${BLUE}ℹ️  Mendeteksi arsitektur Mac:${NC} ${BOLD}${ARCH}${NC}"
if [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}⚠️  Peringatan: Build saat ini dioptimalkan untuk Apple Silicon (M1/M2/M3/M4).${NC}"
    echo -e "${YELLOW}   Jika kamu memakai Intel Mac, aplikasi akan berjalan via emulasi Rosetta 2.${NC}"
fi

# 3. Setup Paths
REPO="arieft23/droid-mirror"
INSTALL_DIR="/Applications"
APP_NAME="DroidMirror.app"
TMP_DIR="/tmp/droidmirror_install"
ZIP_FILE="${TMP_DIR}/DroidMirror.zip"

mkdir -p "$TMP_DIR"

# 4. Fetch Download URL
echo -e "${BLUE}🔍 Mencari versi rilis terbaru dari GitHub...${NC}"

LATEST_URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep "browser_download_url.*zip" \
    | cut -d '"' -f 4 \
    | head -n 1)

# Fallback to direct main tag if releases API returns empty
if [ -z "$LATEST_URL" ]; then
    LATEST_URL="https://github.com/${REPO}/releases/download/v1.0.0/DroidMirror-1.0.0-macOS-arm64.zip"
fi

echo -e "${BLUE}⬇️  Mengunduh DroidMirror...${NC}"
curl -# -L "$LATEST_URL" -o "$ZIP_FILE"

if [ ! -f "$ZIP_FILE" ] || [ ! -s "$ZIP_FILE" ]; then
    echo -e "${RED}❌ Gagal mengunduh file release dari GitHub.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

# 5. Close running instance if any
if pgrep -f "DroidMirror" >/dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  Menutup DroidMirror yang sedang berjalan...${NC}"
    pkill -f "DroidMirror" >/dev/null 2>&1 || true
    sleep 1
fi

# 6. Extract
echo -e "${BLUE}📦 Memasang ke folder /Applications...${NC}"
rm -rf "${INSTALL_DIR}/${APP_NAME}"
unzip -q -o "$ZIP_FILE" -d "$TMP_DIR"

if [ -d "${TMP_DIR}/${APP_NAME}" ]; then
    mv "${TMP_DIR}/${APP_NAME}" "${INSTALL_DIR}/"
elif [ -d "${TMP_DIR}/build/${APP_NAME}" ]; then
    mv "${TMP_DIR}/build/${APP_NAME}" "${INSTALL_DIR}/"
else
    # Find wherever the .app is inside extracted archive
    FOUND_APP=$(find "$TMP_DIR" -name "${APP_NAME}" -maxdepth 2 | head -n 1)
    if [ -n "$FOUND_APP" ]; then
        mv "$FOUND_APP" "${INSTALL_DIR}/"
    else
        echo -e "${RED}❌ Gagal mengekstrak DroidMirror.app dari arsip zip.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

# 7. Bypass Gatekeeper Quarantine automatically
echo -e "${BLUE}🛡️  Membersihkan atribut Gatekeeper (xattr -cr)...${NC}"
xattr -cr "${INSTALL_DIR}/${APP_NAME}" 2>/dev/null || true

# 8. Clean temporary files
rm -rf "$TMP_DIR"

# 9. Success & Open
echo -e ""
echo -e "${GREEN}${BOLD}🎉 DroidMirror berhasil dipasang di /Applications/DroidMirror.app!${NC}"
echo -e "${GREEN}🚀 Membuka aplikasi sekarang...${NC}"
echo -e "--------------------------------------------------------"

open "${INSTALL_DIR}/${APP_NAME}"
