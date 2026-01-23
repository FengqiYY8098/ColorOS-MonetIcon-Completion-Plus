#!/system/bin/sh
# 优化版扫描脚本: 使用 pm list -f 减少 IPC 调用

LOG_FILE="/data/adb/moneticon_tmp/scan.log"
RESULT_FILE="/data/adb/moneticon_tmp/moneticon_apps"

echo "正在准备扫描..." > "$LOG_FILE"
echo "" > "$RESULT_FILE"

# 1. 直接获取所有第三方应用的 路径=包名
# 输出格式示例: package:/data/app/~~.../base.apk=com.example.app
echo "正在获取应用列表..." >> "$LOG_FILE"
RAW_LIST=$(pm list packages -f -3)

# 统计总数 (计算行数)
TOTAL=$(echo "$RAW_LIST" | grep -c "package:")
CURRENT=0

echo "开始高速扫描... (共 $TOTAL 个应用)" >> "$LOG_FILE"

# 使用 IFS read 处理每一行
echo "$RAW_LIST" | while read -r line; do
    # line: package:/path/to/base.apk=com.pkg.name
    
    # 去除 'package:' 前缀
    temp=${line#package:}
    
    # 提取路径 (截取到最后一个 = 之前)
    apk_path=${temp%=*}
    
    # 提取包名 (截取最后一个 = 之后)
    pkg_name=${temp##*=}

    if [ -z "$apk_path" ] || [ -z "$pkg_name" ]; then
        continue
    fi
    
    # 进度计数 (在 while subshell 中计数无法传递给父 shell，但这里只用于打日志)
    # 简单的进度展示: 每 5 个或 10 个更新一次日志，或者每个都更新但可能太快
    # 既然速度很快，直接输出即可
    CURRENT=$((CURRENT + 1))
    
    # 搜索关键字
    if grep -a -q "monochrome" "$apk_path"; then
        echo "$pkg_name" >> "$RESULT_FILE"
    fi
    
    # 输出进度 (前端会解析这个格式)
    echo "PROGRESS:$CURRENT/$TOTAL:$pkg_name" >> "$LOG_FILE"
done

echo "扫描完成。" >> "$LOG_FILE"
echo "DONE" >> "$LOG_FILE"
