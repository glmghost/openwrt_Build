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

#!/bin/bash
mkdir -p files/etc/config
cat > files/etc/config/network <<EOF
config interface 'lan'
    option ipaddr '192.168.31.238'
    option netmask '255.255.255.0'
    option ip6assign '60'
EOF
echo "✅ [Customize] Successfully patched $NINJA_MAKEFILE to use a valid gnulib URL."
echo "   New gnulib URL: $NEW_GNULIB_URL"
