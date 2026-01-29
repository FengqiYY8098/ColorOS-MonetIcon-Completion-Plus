#!/system/bin/sh

MOD_ROOT="/data/adb/modules/ThemedIconCompletion"
CACHE_ROOT="/data/adb/moneticon_tmp"
SCAN_LOG="${CACHE_ROOT}/scan.log"
SCAN_RESULT="${CACHE_ROOT}/moneticon_apps"
WEB_ROOT="${MOD_ROOT}/webroot"
VERSION_FILE="${WEB_ROOT}/version"
ICON_PATH_FILE="${WEB_ROOT}/icon_path"
PKGLIST_FILE="${WEB_ROOT}/pkglist"

scan_monet() {
    mkdir -p "$CACHE_ROOT"
    
    echo "正在准备扫描..." > "$SCAN_LOG"
    echo "" > "$SCAN_RESULT"

    echo "正在获取应用列表..." >> "$SCAN_LOG"
    RAW_LIST=$(pm list packages -f -3)

    TOTAL=$(echo "$RAW_LIST" | grep -c "package:")
    CURRENT=0

    echo "开始扫描... (共 $TOTAL 个应用)" >> "$SCAN_LOG"

    echo "$RAW_LIST" | while read -r line; do
        temp=${line#package:}
        apk_path=${temp%=*}
        pkg_name=${temp##*=}

        if [ -z "$apk_path" ] || [ -z "$pkg_name" ]; then
            continue
        fi

        CURRENT=$((CURRENT + 1))
        
        if grep -a -q "monochrome" "$apk_path"; then
            echo "$pkg_name" >> "$SCAN_RESULT"
        fi
        
        echo "PROGRESS:$CURRENT/$TOTAL:$pkg_name" >> "$SCAN_LOG"
    done

    echo "扫描完成。" >> "$SCAN_LOG"
    echo "DONE" >> "$SCAN_LOG"
}

clean_icon() {
    if [ ! -f "$PKGLIST_FILE" ] || [ ! -s "$PKGLIST_FILE" ]; then
        echo ">>> pkglist 为空或不存在，跳过清理。"
        return
    fi
    
    if [ ! -s "$ICON_PATH_FILE" ]; then
        echo ">>> 未找到配置的图标路径，跳过清理。"
        return
    fi

    echo ">>> 根据 pkglist 清理选中图标 (Blacklist Mode)..."
    
    cat "$ICON_PATH_FILE" | tr -d '\r' | grep -v '^$' | while read -r target_base; do
        [ -z "$target_base" ] && continue
        cat "$PKGLIST_FILE" | tr -d '\r' | grep -v '^$' | while read -r pkg_name; do
            [ -z "$pkg_name" ] && continue
            
            target_dir="$target_base/$pkg_name"
            if [ -d "$target_dir" ]; then
                rm -rf "$target_dir"
                echo "已屏蔽/删除: $target_dir"
            fi
        done
    done

    echo ">>> 清理完成。"
}

scan_paths() {
    for dir in "$MOD_ROOT"/*; do
        if [ ! -d "$dir" ]; then continue; fi
        
        dirname_base=${dir##*/}
        if [ "$dirname_base" = "webroot" ]; then continue; fi
        
        found_file=$(find -L "$dir" -name "monochrome.png" | head -n 1)
        
        if [ -n "$found_file" ]; then
            pkg_dir=$(dirname "$found_file")
            target_path=$(dirname "$pkg_dir")
            
            if [ -d "$target_path" ]; then
                 count=$(find -L "$target_path" -mindepth 1 -maxdepth 1 -type d | wc -l)
                 echo "$target_path|$count"
            fi
        fi
    done
}

update() {
    NEW_VERSION="$1"
    UPDATE_CACHE_DIR="/data/adb/moneticon_tmp"
    
    if [ -s "$ICON_PATH_FILE" ]; then
        echo ">>> 检测到自定义图标路径配置..."
    else
        echo ">>> 使用默认图标路径..."
        echo "${MOD_ROOT}/data/oplus/uxicons/" > "$ICON_PATH_FILE"
        echo "${MOD_ROOT}/my_product/media/theme/uxicons/hdpi/" >> "$ICON_PATH_FILE"
    fi
    
    echo ">>> 解压资源..."
    if [ -f "${UPDATE_CACHE_DIR}/uxicons.zip" ]; then
        unzip -o "${UPDATE_CACHE_DIR}/uxicons.zip" -d "${UPDATE_CACHE_DIR}/" > /dev/null
    fi
    
    if [ -f "${UPDATE_CACHE_DIR}/webui.zip" ]; then
        echo ">>> 更新 WebUI..."
        unzip -o "${UPDATE_CACHE_DIR}/webui.zip" -d "${WEB_ROOT}/" > /dev/null
    fi
    
    echo ">>> 正在合并图标到目标路径..."
    grep -v '^$' "$ICON_PATH_FILE" | while read -r target_path; do
        [ -z "$target_path" ] && continue
        echo " -> 目标: $target_path"
        mkdir -p "$target_path"
        
        if [ -d "${UPDATE_CACHE_DIR}/uxicons" ]; then
            cp -rf "${UPDATE_CACHE_DIR}/uxicons/"* "$target_path"
        elif [ -d "${UPDATE_CACHE_DIR}/" ]; then
            cp -rf "${UPDATE_CACHE_DIR}/uxicons/"* "$target_path" 2>/dev/null
        fi
    done

    echo ">>> 更新版本信息..."
    if [ ! -z "$NEW_VERSION" ]; then
        echo "$NEW_VERSION" > "$VERSION_FILE"
    fi
    
    echo ">>> 清理临时目录..."
    rm -rf "$UPDATE_CACHE_DIR"

    clean_icon
    
    echo ">>> 全部完成 (Success)"
}

case "$1" in
    "scan_monet")
        scan_monet
        ;;
    "clean_icon")
        clean_icon
        ;;
    "scan_paths")
        scan_paths
        ;;
    "update")
        update "$2"
        ;;
    *)
        echo "ColorOS MonetIcon Plus Script"
        echo "Usage: $0 {scan_monet|clean_icon|scan_paths|update <ver>}"
        exit 1
        ;;
esac
