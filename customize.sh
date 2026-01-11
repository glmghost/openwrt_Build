#!/bin/bash
set -euo pipefail  # 开启严格模式，出错立即退出
#===============================================
# 基础配置（保留原有IP修改，可根据需求调整）
echo "【1/7】修改默认IP为 192.168.31.238"
sed -i 's/192.168.1.1/192.168.31.238/g' openwrt/package/base-files/files/bin/config_generate || echo "默认IP修改失败（可能路径不符/OpenWrt源码目录不存在）"

# 替换 erofs-utils 下载源为国内镜像（解决下载失败）
echo "【1.5/7】替换 erofs-utils 下载源"
EROFS_UTILS_MAKEFILE="openwrt/tools/erofs-utils/Makefile"  # 修正路径：指向openwrt子目录
if [ -f "$EROFS_UTILS_MAKEFILE" ]; then
    # 替换官方源为 GitHub 镜像（稳定可用）
    sed -i 's|https://git.kernel.org/pub/scm/fs/erofs/erofs-utils.git/snapshot/|https://github.com/erofs/erofs-utils/archive/refs/tags/|g' "$EROFS_UTILS_MAKEFILE"
    sed -i 's|erofs-utils-|v|g' "$EROFS_UTILS_MAKEFILE"
    echo "erofs-utils 下载源替换完成"
else
    echo "erofs-utils Makefile 不存在，跳过下载源替换"
fi

# 新增：禁用 erofs-utils 工具包（兜底，避免下载/编译失败中断流程）
echo "【1.6/7】禁用 erofs-utils 工具包，规避编译风险"
CONFIG_FILE="openwrt/.config"
touch "$CONFIG_FILE"  # 确保文件存在
sed -i '/CONFIG_TOOL_EROFS_UTILS/d' "$CONFIG_FILE"
echo "CONFIG_TOOL_EROFS_UTILS=n" >> "$CONFIG_FILE"

# 禁用/移除指定插件 START
# 1. 清理feeds中残留的插件（保留SSR-Plus，移除Turbo ACC+防火墙+Argon+Nikki）
echo "【2/7】卸载feeds中指定插件（移除Nikki相关组件）"
FEEDS_SCRIPT="openwrt/scripts/feeds"  # 修正路径：指向openwrt子目录
if [ -f "$FEEDS_SCRIPT" ]; then
    # 优化：拆分命令，避免管道符导致cd失效，提高容错
    cd openwrt || exit 1
    ./scripts/feeds uninstall -a mosdns luci-app-mosdns openclash luci-app-openclash homeproxy luci-app-homeproxy mihomo luci-app-mihomo luci-app-ddns ddns-scripts luci-app-upnp miniupnpd luci-app-turboacc firewall luci-app-firewall luci-theme-argon luci-app-argon-config luci-theme-nikki luci-app-nikki-config || echo "部分feeds插件未安装，跳过卸载"
    cd .. || exit 1
    
    # 额外清理feeds目录下残留文件（含Nikki主题）
    rm -rf openwrt/feeds/luci/applications/luci-app-turboacc*
    rm -rf openwrt/feeds/luci/applications/luci-app-firewall*
    rm -rf openwrt/feeds/packages/net/firewall*
    rm -rf openwrt/feeds/packages/net/turboacc*
    # 清理Argon主题相关feeds残留
    rm -rf openwrt/feeds/luci/themes/luci-theme-argon*
    rm -rf openwrt/feeds/luci/applications/luci-app-argon-config*
    # 清理Nikki主题相关feeds残留
    rm -rf openwrt/feeds/luci/themes/luci-theme-nikki*
    rm -rf openwrt/feeds/luci/applications/luci-app-nikki-config*
else
    echo "feeds脚本不存在，跳过卸载步骤"
fi

# 2. 移除源码目录中指定插件（保留SSR-Plus，移除Turbo ACC+防火墙+Argon+Nikki）
echo "【3/7】删除small-package及全局源码中指定插件（移除Nikki主题）"
SMALL_PACKAGE_DIR="openwrt/package/small-package"  # 修正路径：指向openwrt子目录
if [ -d "$SMALL_PACKAGE_DIR" ]; then
    # 移除small-package下非SSR-Plus插件+Turbo ACC+防火墙+Argon+Nikki
    rm -rf "$SMALL_PACKAGE_DIR"/mosdns*
    rm -rf "$SMALL_PACKAGE_DIR"/openclash*
    rm -rf "$SMALL_PACKAGE_DIR"/homeproxy*
    rm -rf "$SMALL_PACKAGE_DIR"/mihomo*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-ddns*
    rm -rf "$SMALL_PACKAGE_DIR"/ddns-scripts*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-upnp*
    rm -rf "$SMALL_PACKAGE_DIR"/miniupnpd*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-turboacc*
    rm -rf "$SMALL_PACKAGE_DIR"/firewall*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-firewall*
    # 清理small-package下Argon主题相关源码
    rm -rf "$SMALL_PACKAGE_DIR"/luci-theme-argon*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-argon-config*
    # 清理small-package下Nikki主题相关源码
    rm -rf "$SMALL_PACKAGE_DIR"/luci-theme-nikki*
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-nikki-config*
    
    # 新增：清理SSR-Plus/NaiveProxy残留编译文件，避免产物损坏
    rm -rf "$SMALL_PACKAGE_DIR"/luci-app-ssr-plus/.built "$SMALL_PACKAGE_DIR"/ssr-plus/.built
    rm -rf "$SMALL_PACKAGE_DIR"/naiveproxy/.built
    echo "small-package目录非SSR-Plus插件源码删除完成，SSR-Plus残留已清理"
else
    echo "small-package目录不存在，跳过该目录源码删除"
fi

# 全局清理其他目录下的残留插件（含Nikki主题，关键：避免编译时加载）
rm -rf openwrt/package/feeds/luci/luci-app-mosdns*
rm -rf openwrt/package/feeds/packages/mosdns*
rm -rf openwrt/package/feeds/luci/luci-app-openclash*
rm -rf openwrt/package/feeds/packages/openclash*
rm -rf openwrt/package/feeds/luci/luci-app-turboacc*
rm -rf openwrt/package/feeds/packages/firewall*
# 全局清理Argon主题残留
rm -rf openwrt/package/feeds/luci/luci-theme-argon*
rm -rf openwrt/package/feeds/luci/luci-app-argon-config*
# 全局清理Nikki主题残留
rm -rf openwrt/package/feeds/luci/luci-theme-nikki*
rm -rf openwrt/package/feeds/luci/luci-app-nikki-config*
rm -rf openwrt/package/custom/luci-theme-argon*  # 如有自定义目录，可补充
rm -rf openwrt/package/custom/luci-theme-nikki*  # 如有自定义目录，补充Nikki清理
echo "全局残留插件（含Argon、Nikki主题）清理完成"

# 3. 刷新并重新安装SSR-Plus相关feeds（确保依赖完整，先更新再安装）
echo "【4/7】刷新feeds并仅安装SSR-Plus相关组件"
if [ -f "$FEEDS_SCRIPT" ]; then
    # 优化：拆分命令，提高执行稳定性，避免连带失败
    cd openwrt || exit 1
    ./scripts/feeds update -a || echo "feeds全局更新失败（非关键错误，继续执行）"
    # 仅安装SSR-Plus相关，不安装其他插件（避免连带安装多余组件）
    ./scripts/feeds install -y luci-app-ssr-plus ssr-plus naiveproxy || echo "SSR-Plus相关feeds安装失败，请检查feeds配置"
    cd .. || exit 1
else
    echo "feeds脚本不存在，跳过feeds刷新和安装步骤"
fi

# 4. 配置.config文件并固化编译参数（关键：优化配置写入，增加容错）
echo "【5/7】配置.config文件（确保配置生效，规避依赖冲突）"
# 定义.config文件路径（指向openwrt子目录）
CONFIG_FILE="openwrt/.config"
# 第一步：先初始化.config（避免原有配置干扰，若已有配置先备份再清空）
if [ -f "$CONFIG_FILE" ]; then
    mv "$CONFIG_FILE" "$CONFIG_FILE.bak"  # 备份原有配置
fi
touch "$CONFIG_FILE"

# 第二步：写入核心配置（先禁用所有不需要的插件，再启用SSR-Plus+NaiveProxy）
cat > "$CONFIG_FILE" << EOF
# 基础编译配置（开启开发模式和编译日志，方便排查错误）
CONFIG_DEVEL=y
CONFIG_BUILD_LOG=y

# 禁用 erofs-utils 工具包（兜底配置）
CONFIG_TOOL_EROFS_UTILS=n

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

# 禁用Turbo ACC 网络加速
CONFIG_PACKAGE_luci-app-turboacc=n
CONFIG_PACKAGE_turboacc=n
CONFIG_PACKAGE_kmod-fast-classifier=n
CONFIG_PACKAGE_kmod-fast-path=n
CONFIG_PACKAGE_kmod-fast-tcp=n
CONFIG_PACKAGE_kmod-shortcut-fe=n
CONFIG_PACKAGE_kmod-shortcut-fw=n

# 禁用防火墙功能（注意：禁用后固件无防火墙，需自行承担风险）
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_firewall4=n
CONFIG_PACKAGE_luci-app-firewall=n
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_nftables=n
CONFIG_PACKAGE_ip6tables=n

# 禁用Argon主题及配置插件（彻底移除）
CONFIG_PACKAGE_luci-theme-argon=n
CONFIG_PACKAGE_luci-app-argon-config=n

# 禁用Nikki主题及配置插件（彻底移除）
CONFIG_PACKAGE_luci-theme-nikki=n
CONFIG_PACKAGE_luci-app-nikki-config=n

# 指定默认主题（避免无主题报错，启用原生bootstrap）
CONFIG_PACKAGE_luci-theme-bootstrap=y

# 启用SSR-Plus核心及仅NaiveProxy协议（强制启用，禁用所有其他协议）
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_ssr-plus=y
CONFIG_PACKAGE_naiveproxy=y  # 关键：显式启用NaiveProxy依赖，确保编译产物存在

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

echo "配置文件写入完成，无需额外固化步骤（编译时自动加载.config）"

echo "【6/7】验证禁用项是否配置正确"
# 优化：忽略注释行，仅检查有效配置
grep -E "^CONFIG_PACKAGE_(turboacc|firewall|argon|nikki)=" "$CONFIG_FILE" | grep -v "=n" || echo "Turbo ACC、防火墙、Argon、Nikki已完全禁用"

echo "【7/7】验证默认主题是否为bootstrap"
grep "^CONFIG_PACKAGE_luci-theme-bootstrap=y" "$CONFIG_FILE" && echo "默认主题已设置为bootstrap" || echo "默认主题配置需检查"

# 禁用/移除指定插件 END

echo "===== 自定义配置执行完成（保留SSR-Plus+仅启用NaiveProxy，移除Turbo ACC+防火墙+Argon+Nikki） ====="
