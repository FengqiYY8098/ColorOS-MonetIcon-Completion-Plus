#!/system/bin/sh

MOD_ROOT="/data/adb/modules/ThemedIconCompletion"
CACHE_ROOT="/data/adb/uxicons_cache_tmp"
TARGET_PATH1="${MOD_ROOT}/my_product/media/theme/uxicons/hdpi/"
TARGET_PATH2="${MOD_ROOT}/data/oplus/uxicons/"
DELETE_LIST="${CACHE_ROOT}/delete_packages.txt"

if [ ! -f "$DELETE_LIST" ]; then
    echo "错误: 删除列表文件不存在"
    exit 1
fi

echo "开始清理图标..."
echo "----------------------------------------"

while IFS= read -r pkg_name; do
    # 跳过空行和注释
    if [ -z "$pkg_name" ] || [ "${pkg_name#\#}" != "$pkg_name" ]; then
        continue
    fi
    
    # 删除第一个路径下的文件夹
    if [ -d "${TARGET_PATH1}${pkg_name}" ]; then
        rm -rf "${TARGET_PATH1}${pkg_name}"
        echo "已删除: ${TARGET_PATH1}${pkg_name}"
    fi
    
    # 删除第二个路径下的文件夹
    if [ -d "${TARGET_PATH2}${pkg_name}" ]; then
        rm -rf "${TARGET_PATH2}${pkg_name}"
        echo "已删除: ${TARGET_PATH2}${pkg_name}"
    fi
done < "$DELETE_LIST"

# 清理删除列表文件
rm -f "$DELETE_LIST"

echo "----------------------------------------"
echo "清理完成。"
