#!/bin/bash
#===============================================
# Modify default IP
#sed -i 's/192.168.1.1/192.168.31.238/g' /package/base-files/files/bin/config_generate
#sed -i 's/192.168.1.1/192.168.31.238/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/kenzo/g' /package/base-files/files/bin/config_generate

#2. Custom settings
#sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
#sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite/' package/Makefile
#sed -i 's/root:.*/root:$1$tTPCBw1t$ldzfp37h5lSpO9VXk4uUE\/:18336:0:99999:7:::/g' package/base-files/files/etc/shadow
#!/bin/bash
#
# customize.sh - Fix for ninja gnulib download failure in OpenWrt build
# This script patches the ninja Makefile to use a valid gnulib download URL.
#

set -e

echo "🔧 [Customize] Applying fix for ninja gnulib download issue..."

# Define the path to the ninja Makefile within the OpenWrt source tree
NINJA_MAKEFILE="openwrt/tools/ninja/Makefile"

# Check if the file exists
if [ ! -f "$NINJA_MAKEFILE" ]; then
    echo "⚠️  [Customize] Warning: $NINJA_MAKEFILE not found. Skipping ninja fix."
    exit 0
fi

# Create a backup of the original Makefile
cp "$NINJA_MAKEFILE" "${NINJA_MAKEFILE}.bak"

# The correct gnulib commit hash used by the patch
GNULIB_COMMIT="c99c8d491850dc3a6e0b8604a2729d8bc5c0eff1"

# The new, working URL from a GNU mirror
NEW_GNULIB_URL="https://git.savannah.gnu.org/cgit/gnulib.git/snapshot/gnulib-${GNULIB_COMMIT}.tar.gz"

# Use sed to replace the broken PKG_SOURCE_URL and PKG_SOURCE definitions
# We are replacing the entire block that defines the gnulib package
cat > "$NINJA_MAKEFILE" << EOF
# SPDX-License-Identifier: GPL-2.0-only
#
include \$(TOPDIR)/rules.mk

PKG_NAME:=ninja
PKG_VERSION:=1.12.1

PKG_SOURCE:=ninja-\$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/ninja-build/ninja/archive/v\$(PKG_VERSION)
PKG_HASH:=5376e3d3851b31e672b19f2d306e87bf010e8be0e1ff95d65c5a67a3a61057cf

PKG_HOST_ONLY:=1
PKG_BUILD_DIR=\$(BUILD_DIR_HOST)/ninja-\$(PKG_VERSION)

include \$(INCLUDE_DIR)/host-build.mk

define Host/Prepare
    \$(call Host/Prepare/Default)
    # Apply gnulib as a subdirectory
    mkdir -p \$(PKG_BUILD_DIR)/gnulib
    tar -xf \$(DL_DIR)/gnulib-$(GNULIB_COMMIT).tar.gz -C \$(PKG_BUILD_DIR)/gnulib --strip-components=1
endef

define Host/Compile
    cd \$(PKG_BUILD_DIR) && \
    \$(HOST_PYTHON) configure.py --bootstrap
endef

define Host/Install
    \$(INSTALL_DIR) \$(STAGING_DIR_HOST)/bin
    \$(INSTALL_BIN) \$(PKG_BUILD_DIR)/ninja \$(STAGING_DIR_HOST)/bin/
endef

# Override the default Download method to fetch gnulib from a working URL
define Download/gnulib
  FILE:=gnulib-$(GNULIB_COMMIT).tar.gz
  URL:=$(NEW_GNULIB_URL)
  HASH:=skip
endef
\$(eval \$(call Download,gnulib))

\$(eval \$(call HostBuild))
EOF

echo "✅ [Customize] Successfully patched $NINJA_MAKEFILE to use a valid gnulib URL."
echo "   New gnulib URL: $NEW_GNULIB_URL"
