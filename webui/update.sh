#!/system/bin/sh

# === 路径配置 ===
MOD_DIR="/data/adb/modules/ThemedIconCompletion"
WEB_ROOT="$MOD_DIR/webroot"
VERSION_FILE="$WEB_ROOT/version"

# 临时缓存目录
CACHE_DIR="/data/adb/moneticon_tmp"

# 下载的 zip 路径
ZIP_FILE="$CACHE_DIR/uxicons.zip"
WEBUI_ZIP="$CACHE_DIR/webui.zip"

# 目标路径
TARGET_A="$MOD_DIR/data/oplus/uxicons/"
TARGET_B="$MOD_DIR/my_product/media/theme/uxicons/hdpi/"

# 传入的新版本号参数
NEW_VERSION="$1"

# === 内部函数 ===
cleanup_cache() {
    echo ">>> 清理临时目录..."
    if [ -d "$CACHE_DIR" ]; then
        # 直接删除整个缓存目录，因为扫描结果已经移出去了
        rm -rf "$CACHE_DIR"
    fi
}

# === 开始执行 ===
echo ">>> 脚本开始执行 (Root)..."
echo ">>> 正在处理缓存: $CACHE_DIR"

# 1. 检查文件是否存在
if [ ! -f "$ZIP_FILE" ]; then
    echo "错误: 在缓存目录找不到 uxicons.zip"
    exit 1
fi

echo ">>> 正在解压图标包..."
# 解压到缓存目录
unzip -o "$ZIP_FILE" -d "$CACHE_DIR" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "错误: 解压失败，文件可能损坏"
    rm -f "$ZIP_FILE" # 只删除损坏的压缩包，保留其他可能有用的数据
    cleanup_cache
    exit 1
fi

# 2. 检查 WebUI 更新包
if [ -f "$WEBUI_ZIP" ]; then
    echo ">>> 发现 WebUI 包，正在部署..."
    # 解压到模块根目录
    unzip -o "$WEBUI_ZIP" -d "$MOD_DIR" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "警告: WebUI 更新失败"
    else
        echo "WebUI 已更新"
    fi
fi

echo ">>> 正在合并图标..."
# 确保目标目录存在
mkdir -p "$TARGET_A"
mkdir -p "$TARGET_B"

# 复制文件 (cp -rf)
# 将 uxicons 里的所有内容复制到目标目录
cp -rf "$CACHE_DIR/uxicons/"* "$TARGET_A"
cp -rf "$CACHE_DIR/uxicons/"* "$TARGET_B"

echo ">>> 更新版本信息..."
if [ ! -z "$NEW_VERSION" ]; then
    echo "$NEW_VERSION" > "$VERSION_FILE"
fi

# === 新增: 根据 pkglist 还原图标 ===
PKGLIST="$WEB_ROOT/pkglist"
if [ -f "$PKGLIST" ]; then
    echo ">>> 检测到 pkglist，正在执行定向还原..."
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        # 跳过空行
        [ -z "$pkg" ] && continue
        
        echo "   正在还原: $pkg"
        # 删除对应图标文件夹 (恢复为系统默认)
        rm -rf "$TARGET_A/$pkg"
        rm -rf "$TARGET_B/$pkg"
    done < "$PKGLIST"
fi

cleanup_cache

echo ">>> 全部完成 (Success)"
exit 0