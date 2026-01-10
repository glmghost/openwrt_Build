#!/bin/bash
set -euo pipefail  # 开启严格模式，出错立即退出
#===============================================
# 基础配置（保留原有IP修改，可根据需求调整）
echo "【1/5】修改默认IP为 192.168.1.251"
sed -i 's/192.168.1.1/192.168.1.251/g' openwrt/package/base-files/files/bin/config_generate || echo "默认IP修改失败（可能路径不符）"

# 禁用/移除指定插件 START
# 1. 清理feeds中残留的插件（仅卸载非SSR-Plus的插件）
echo "【2/5】卸载feeds中指定插件（保留SSR-Plus）"
if [ -f ./scripts/feeds ]; then
    ./scripts/feeds uninstall -a mosdns luci-app-mosdns openclash luci-app-openclash homeproxy luci-app-homeproxy mihomo luci-app-mihomo luci-app-ddns ddns-scripts luci-app-upnp miniupnpd || echo "部分feeds插件未安装，跳过卸载"
else
    echo "feeds脚本不存在，跳过卸载步骤"
fi

# 2. 移除源码目录中指定插件（仅删除非SSR-Plus的插件）
echo "【3/5】删除small-package中指定插件源码（保留SSR-Plus）"
SMALL_PACKAGE_DIR="package/small-package"
if [ -d "$SMALL_PACKAGE_DIR" ]; then
    # 移除除SSR-Plus外的其他插件
    rm -rf "$SMALL_PACKAGE_DIR"/mosdns*
    rm -rf "$SMALL_PACKAGE_DIR"/openclash*
    rm -rf "$SMALL_PACKAGE_DIR"/homeproxy*
    rm -rf "$SMALL_PACKAGE_DIR"/mihomo*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-ddns*
    rm -rf "$SMALL_PACKAGE_DIR"/ddns-scripts*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-upnp*
    rm -rf "$SMALL_PACKAGE_DIR"/miniupnpd*
    echo "非SSR-Plus插件源码删除完成"
else
    echo "small-package目录不存在，跳过源码删除"
fi

# 3. 配置编译开关（禁用其他插件+启用SSR-Plus并仅保留NaiveProxy）
echo "【4/5】写入插件编译配置到.config"
# 确保.config文件存在
touch .config

# ========== 关键修改：SSR-Plus相关配置 ==========
# 先清空原有SSR-Plus相关配置（避免冲突）
sed -i '/CONFIG_PACKAGE_luci-app-ssr-plus/d' .config
sed -i '/CONFIG_PACKAGE_ssr-plus/d' .config

# 启用SSR-Plus主程序+仅启用NaiveProxy协议（禁用其他所有协议）
cat >> .config << EOF
# 启用SSR-Plus核心
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_ssr-plus=y

# 仅保留NaiveProxy协议（其他协议全部禁用）
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_Plugin=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Libev=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_Obfs=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Obfs_OpenSSL=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Clash=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Clash_Dashboard=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Clash_TUN=n
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Clash_Extra=n
EOF

# ========== 其他插件仍保持禁用 ==========
# 清空原有非SSR-Plus插件配置
sed -i '/CONFIG_PACKAGE_mosdns/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-mosdns/d' .config
sed -i '/CONFIG_PACKAGE_openclash/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-openclash/d' .config
sed -i '/CONFIG_PACKAGE_homeproxy/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-homeproxy/d' .config
sed -i '/CONFIG_PACKAGE_mihomo/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-mihomo/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-ddns/d' .config
sed -i '/CONFIG_PACKAGE_ddns-scripts/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-upnp/d' .config
sed -i '/CONFIG_PACKAGE_miniupnpd/d' .config

# 写入其他插件禁用配置
cat >> .config << EOF
CONFIG_PACKAGE_mosdns=n
CONFIG_PACKAGE_luci-app-mosdns=n
CONFIG_PACKAGE_openclash=n
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_homeproxy=n
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_mihomo=n
CONFIG_PACKAGE_luci-app-mihomo=n
CONFIG_PACKAGE_luci-app-ddns=n
CONFIG_PACKAGE_ddns-scripts=n
CONFIG_PACKAGE_luci-app-upnp=n
CONFIG_PACKAGE_miniupnpd=n
EOF

# 4. 刷新feeds（确保配置生效）
echo "【5/5】刷新feeds配置"
if [ -f ./scripts/feeds ]; then
    ./scripts/feeds update -a || echo "feeds刷新失败（非关键错误，继续执行）"
    ./scripts/feeds install -a luci-app-ssr-plus ssr-plus || echo "SSR-Plus feeds安装失败（手动检查依赖）"
fi
# 禁用/移除指定插件 END

# 保留的其他自定义配置（按需注释/启用）
# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/kenzo/g' openwrt/package/base-files/files/bin/config_generate

# 其他自定义项
#sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
#sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite/' package/Makefile
#sed -i 's/root:.*/root:$1$tTPCBw1t$ldzfp37h5lSpO9VXk4uUE\/:18336:0:99999:7:::/g' package/base-files/files/etc/shadow

echo "===== 自定义配置执行完成（保留SSR-Plus+仅启用NaiveProxy） ====="
