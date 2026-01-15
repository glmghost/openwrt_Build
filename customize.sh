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
# customize.sh - 解决kmod编译问题（保留kmod，深度修复方案）
# 脚本执行目录：GitHub项目根目录（与openwrt目录同级）

set -e  # 遇到错误立即终止脚本，方便排查

echo "======================================"
echo "开始执行自定义配置，深度修复kmod编译问题"
echo "======================================"

# 切换到openwrt目录（核心：所有操作针对openwrt编译目录）
cd ./openwrt || { echo "错误：未找到openwrt目录"; exit 1; }

echo "步骤1：清理旧的kmod源码，避免损坏/不完整导致编译失败"
rm -rf feeds/packages/utils/kmod 2>/dev/null || true
if [ ! -d "feeds/packages/utils/kmod" ]; then
  echo "✅ 旧kmod源码已清理完成"
else
  echo "⚠️  旧kmod源码清理失败，可能影响后续操作"
fi

echo "步骤2：重新拉取packages feeds，获取完整kmod源码"
./scripts/feeds update packages || { echo "错误：拉取packages feeds失败"; exit 1; }
echo "✅ packages feeds重新拉取完成"

echo "步骤3：单独安装kmod包，确保依赖完整"
./scripts/feeds install -p packages kmod || { echo "错误：安装kmod包失败"; exit 1; }
echo "✅ kmod包已成功安装，依赖补全完成"

echo "步骤4：替换为兼容lede内核的kmod版本（解决版本不兼容）"
# 克隆openwrt-23.05分支的kmod（与Lean/lede master兼容性最优）
rm -rf temp-packages 2>/dev/null || true
git clone --depth 1 https://github.com/openwrt/packages.git -b openwrt-23.05 temp-packages || { echo "错误：克隆兼容kmod源码失败"; exit 1; }
cp -rf temp-packages/utils/kmod feeds/packages/utils/kmod
rm -rf temp-packages  # 清理临时文件
echo "✅ 兼容版本kmod源码已替换完成"

echo "步骤5：补全kmod与内核的依赖配置，避免编译冲突"
# 静默补全配置，自动填充缺失的内核选项
if [ -e .config ]; then
  make menuconfig -q || { echo "错误：补全配置失败"; exit 1; }
  make kernel_oldconfig || { echo "错误：同步内核配置失败"; exit 1; }
  echo "✅ kmod内核依赖配置补全完成"
else
  echo "⚠️  未找到.config文件，跳过配置补全"
fi

echo "步骤6：保留原有自定义配置（按需保留，与你的原脚本逻辑一致）"
# 以下是你原有脚本中的核心逻辑（可根据你的实际需求补充）
sed -i "s/%D %V, %C/openwrt $(date +'%m.%d') by kenzo/g" package/base-files/files/etc/banner
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

echo "======================================"
echo "自定义配置执行完成，kmod修复逻辑已落地"
echo "======================================"
