#!/bin/bash
set -euo pipefail  # 开启严格模式，出错立即退出
#===============================================
# 基础配置（保留原有IP修改，可根据需求调整）
echo "【1/6】修改默认IP为 192.168.31.238"
sed -i 's/192.168.1.1/192.168.31.238/g' openwrt/package/base-files/files/bin/config_generate || echo "默认IP修改失败（可能路径不符）"

# 替换 erofs-utils 下载源为国内镜像（解决下载失败）
echo "【1.5/6】替换 erofs-utils 下载源"
EROFS_UTILS_MAKEFILE="tools/erofs-utils/Makefile"
if [ -f "$EROFS_UTILS_MAKEFILE" ]; then
    # 替换官方源为 GitHub 镜像（稳定可用）
    sed -i 's|https://git.kernel.org/pub/scm/fs/erofs/erofs-utils.git/snapshot/|https://github.com/erofs/erofs-utils/archive/refs/tags/|g' "$EROFS_UTILS_MAKEFILE"
    sed -i 's|erofs-utils-|v|g' "$EROFS_UTILS_MAKEFILE"
    echo "erofs-utils 下载源替换完成"
else
    echo "erofs-utils Makefile 不存在，跳过下载源替换"
fi

# 禁用/移除指定插件 START
# 1. 清理feeds中残留的插件（仅卸载非SSR-Plus的插件）
echo "【2/6】卸载feeds中指定插件（保留SSR-Plus）"
if [ -f ./scripts/feeds ]; then
    ./scripts/feeds uninstall -a mosdns luci-app-mosdns openclash luci-app-openclash homeproxy luci-app-homeproxy mihomo luci-app-mihomo luci-app-ddns ddns-scripts luci-app-upnp miniupnpd || echo "部分feeds插件未安装，跳过卸载"
    # 额外清理feeds目录下的残留文件（关键：避免编译时重新加载）
    rm -rf feeds/luci/applications/luci-app-mosdns*
    rm -rf feeds/luci/applications/luci-app-openclash*
    rm -rf feeds/luci/applications/luci-app-homeproxy*
    rm -rf feeds/luci/applications/luci-app-mihomo*
    rm -rf feeds/luci/applications/luci-app-ddns*
    rm -rf feeds/packages/net/mosdns*
    rm -rf feeds/packages/net/openclash*
    rm -rf feeds/packages/net/homeproxy*
    rm -rf feeds/packages/net/mihomo*
else
    echo "feeds脚本不存在，跳过卸载步骤"
fi

# 2. 移除源码目录中指定插件（仅删除非SSR-Plus的插件，增加全局清理）
echo "【3/6】删除small-package及全局源码中指定插件（保留SSR-Plus）"
SMALL_PACKAGE_DIR="package/small-package"
if [ -d "$SMALL_PACKAGE_DIR" ]; then
    # 移除small-package下非SSR-Plus插件
    rm -rf "$SMALL_PACKAGE_DIR"/mosdns*
    rm -rf "$SMALL_PACKAGE_DIR"/openclash*
    rm -rf "$SMALL_PACKAGE_DIR"/homeproxy*
    rm -rf "$SMALL_PACKAGE_DIR"/mihomo*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-ddns*
    rm -rf "$SMALL_PACKAGE_DIR"/ddns-scripts*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-upnp*
    rm -rf "$SMALL_PACKAGE_DIR"/miniupnpd*
    echo "small-package目录非SSR-Plus插件源码删除完成"
else
    echo "small-package目录不存在，跳过该目录源码删除"
fi

# 全局清理其他目录下的残留插件（关键：避免编译时加载）
rm -rf package/feeds/luci/luci-app-mosdns*
rm -rf package/feeds/packages/mosdns*
rm -rf package/feeds/luci/luci-app-openclash*
rm -rf package/feeds/packages/openclash*
rm -rf package/custom/mosdns* （如有自定义目录，可补充）
echo "全局残留插件清理完成"

# 3. 刷新并重新安装SSR-Plus相关feeds（确保依赖完整，先更新再安装）
echo "【4/6】刷新feeds并仅安装SSR-Plus相关组件"
if [ -f ./scripts/feeds ]; then
    ./scripts/feeds update -a || echo "feeds全局更新失败（非关键错误，继续执行）"
    # 仅安装SSR-Plus相关，不安装其他插件（避免连带安装多余组件）
    ./scripts/feeds install -y luci-app-ssr-plus ssr-plus naiveproxy || echo "SSR-Plus相关feeds安装失败，请检查feeds配置"
fi

# 4. 配置编译开关（禁用其他插件+启用SSR-Plus并仅保留NaiveProxy）
echo "【5/6】配置.config文件并固化编译参数（关键：确保配置生效）"
# 第一步：先初始化.config（避免原有配置干扰，若已有配置先备份再清空）
if [ -f .config ]; then
    mv .config .config.bak  # 备份原有配置
fi
touch .config

# 第二步：写入核心配置（先禁用所有多余插件，再启用SSR-Plus+NaiveProxy）
cat > .config << EOF
# 基础编译配置（可根据你的设备补充，此处保留核心插件配置）
CONFIG_DEVEL=y
CONFIG_BUILD_LOG=y

# 禁用所有不需要的插件（全局禁用）
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

# 启用SSR-Plus核心及仅NaiveProxy协议（强制启用，禁用所有其他协议）
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_ssr-plus=y
CONFIG_PACKAGE_naiveproxy=y  # 关键：显式启用NaiveProxy依赖

# 仅保留NaiveProxy协议，其他协议全部强制禁用（无默认值，明确赋值n）
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

# 第三步：关键操作 - 固化.config配置，确保编译系统识别（解决配置被覆盖问题）
# 方法1：使用OpenWrt官方工具固化配置
./scripts/config --file .config -e CONFIG_PACKAGE_luci-app-ssr-plus
./scripts/config --file .config -e CONFIG_PACKAGE_ssr-plus
./scripts/config --file .config -e CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy
# 强制禁用其他协议（双重保障）
./scripts/config --file .config -d CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray
./scripts/config --file .config -d CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray
./scripts/config --file .config -d CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Clash

# 方法2：执行make defconfig生成最终有效配置（核心：让OpenWrt识别手动配置）
make defconfig || echo "生成defconfig失败，请检查.config语法是否正确"

echo "【6/6】编译配置固化完成，仅保留SSR-Plus+NaiveProxy"
# 禁用/移除指定插件 END

echo "===== 自定义配置执行完成（保留SSR-Plus+仅启用NaiveProxy） ====="
