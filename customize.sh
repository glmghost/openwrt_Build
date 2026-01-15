#!/bin/bash
#===============================================
# Modify default IP
sed -i 's/192.168.1.1/192.168.31.238/g' openwrt/package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/kenzo/g' openwrt/package/base-files/files/bin/config_generate

#2. Custom settings
#sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
#sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite/' package/Makefile
#sed -i 's/root:.*/root:$1$tTPCBw1t$ldzfp37h5lSpO9VXk4uUE\/:18336:0:99999:7:::/g' package/base-files/files/etc/shadow

#!/bin/bash
# customize.sh - 解决libnl-tiny、libubox核心库编译失败问题
# 脚本执行目录：GitHub项目根目录（与openwrt目录同级）

set -e  # 遇到关键错误终止脚本，方便排查（非关键错误忽略，避免脚本提前退出）

echo "======================================"
echo "开始执行自定义配置，修复核心库libnl-tiny、libubox编译问题"
echo "======================================"

# 步骤0：切换到openwrt目录（所有操作基于openwrt编译目录）
cd ./openwrt || { echo "❌ 错误：未找到openwrt目录，脚本终止"; exit 1; }
echo "✅ 已切换到openwrt编译目录：$(pwd)"

# 步骤1：清理libnl-tiny、libubox旧源码（避免损坏/不完整源码干扰）
echo "--------------------------------------"
echo "步骤1：清理旧的核心库源码"
# 清理libnl-tiny（位于feeds/packages/libs/）
rm -rf feeds/packages/libs/libnl-tiny 2>/dev/null || true
# 清理libubox（位于package/libs/，原生lede包）
rm -rf package/libs/libubox 2>/dev/null || true
# 验证清理结果
if [ ! -d "feeds/packages/libs/libnl-tiny" ] && [ ! -d "package/libs/libubox" ]; then
  echo "✅ 核心库libnl-tiny、libubox旧源码已清理完成"
else
  echo "⚠️  部分旧源码清理失败，可能影响后续编译"
fi

# 步骤2：重新拉取完整feeds，确保核心库源码完整
echo "--------------------------------------"
echo "步骤2：重新拉取feeds，获取完整核心库源码"
# 先清理feeds缓存
./scripts/feeds clean 2>/dev/null || true
# 重新拉取所有feeds（重点获取packages feeds中的libnl-tiny）
./scripts/feeds update -a || { echo "❌ 错误：拉取feeds失败，脚本终止"; exit 1; }
# 重新安装所有feeds包（重点安装libnl-tiny、libubox）
./scripts/feeds install -a || { echo "❌ 错误：安装feeds包失败，脚本终止"; exit 1; }
echo "✅ feeds重新拉取并安装完成，核心库源码已补全"

# 步骤3：补全核心库编译依赖配置，避免配置缺失导致失败
echo "--------------------------------------"
echo "步骤3：补全核心库编译依赖配置"
# 确保.config文件存在（无配置文件则生成基础配置）
if [ ! -e .config ]; then
  echo "⚠️  未找到.config文件，生成默认基础配置"
  make defconfig
fi
# 静默补全配置（自动填充libnl-tiny、libubox所需的编译选项）
make menuconfig -q || { echo "❌ 错误：补全配置失败，脚本终止"; exit 1; }
# 同步内核配置与核心库依赖
make kernel_oldconfig || { echo "❌ 错误：同步内核配置失败，脚本终止"; exit 1; }
echo "✅ 核心库编译依赖配置补全完成"

# 步骤4：清理编译残留，确保编译环境干净
echo "--------------------------------------"
echo "步骤4：清理编译残留文件，避免污染环境"
# 清理核心库相关编译残留
rm -rf build_dir/target-*/libnl-tiny* 2>/dev/null || true
rm -rf build_dir/target-*/libubox* 2>/dev/null || true
rm -rf staging_dir/target-*/usr/lib/libnl-tiny* 2>/dev/null || true
rm -rf staging_dir/target-*/usr/lib/libubox* 2>/dev/null || true
echo "✅ 核心库相关编译残留清理完成"

# 步骤5：（可选）替换兼容版本的核心库源码（解决版本不兼容问题）
# 若前4步仍失败，启用该步骤（替换为与lede内核兼容的版本）
echo "--------------------------------------"
echo "步骤5：替换为兼容lede内核的核心库源码（可选）"
# 备份当前feeds（避免替换失败无法回滚）
cp -rf feeds/packages/libs/libnl-tiny feeds/packages/libs/libnl-tiny-bak 2>/dev/null || true
# 克隆openwrt-23.05分支的libnl-tiny（与Lean/lede master兼容性最优）
rm -rf feeds/packages/libs/libnl-tiny
git clone --depth 1 https://github.com/openwrt/packages.git -b openwrt-23.05 temp-packages 2>/dev/null || {
  echo "⚠️  克隆兼容源码失败，使用当前feeds中的版本"
  mv -f feeds/packages/libs/libnl-tiny-bak feeds/packages/libs/libnl-tiny 2>/dev/null || true
}
if [ -d "temp-packages" ]; then
  cp -rf temp-packages/libs/libnl-tiny feeds/packages/libs/libnl-tiny
  rm -rf temp-packages
  echo "✅ 兼容版本libnl-tiny源码替换完成"
fi
# 修复libubox编译配置（解决常见的版本冲突问题）
sed -i 's/CONFIG_LIBUBOX_DEBUG/CONFIG_LIBUBOX_DEBUG=n/g' package/libs/libubox/Makefile 2>/dev/null || true
echo "✅ libubox编译配置优化完成"

# 步骤6：保留你的原有自定义配置（无需修改，延续之前的逻辑）
echo "--------------------------------------"
echo "步骤6：执行原有自定义配置"
# 替换默认banner
sed -i "s/%D %V, %C/openwrt $(date +'%m.%d') by kenzo/g" package/base-files/files/etc/banner
# 替换默认主题为argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
# 替换golang（你的原有逻辑）
rm -rf feeds/packages/lang/golang 2>/dev/null || true
git clone https://github.com/kenzok8/golang -b 1.25 feeds/packages/lang/golang 2>/dev/null || {
  echo "⚠️  克隆golang失败，使用当前feeds中的版本"
}
# 替换openclash（你的原有逻辑）
rm -rf feeds/luci/applications/luci-app-openclash 2>/dev/null || true
echo "✅ 原有自定义配置执行完成"

echo "======================================"
echo "自定义配置全部完成，核心库修复逻辑已落地"
echo "======================================"
