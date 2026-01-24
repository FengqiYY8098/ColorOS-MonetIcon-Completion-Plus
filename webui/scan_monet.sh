#!/system/bin/sh
# scan_monet.sh - Filtered Sequential Scanner

# === 1. Environment Setup ===
TMP_DIR="/data/adb/moneticon_tmp"
PROGRESS_FILE="$TMP_DIR/progress.json"
RESULT_FILE="$TMP_DIR/moneticon_apps"
# Temp files for processing
SKIP_FILE="$TMP_DIR/skip_list.txt"
SCAN_LIST_FILE="$TMP_DIR/to_scan_list.txt"
LOG_FILE="$TMP_DIR/scan.log"

# Init Env
mkdir -p "$TMP_DIR"
rm -f "$PROGRESS_FILE" "$SKIP_FILE" "$SCAN_LIST_FILE"

# Trap signals logic
cleanup() {
    rm -f "$PROGRESS_FILE" "$SKIP_FILE" "$SCAN_LIST_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

# === 2. Configuration ===
MODDIR=${0%/*}
AAPT_DIR="$MODDIR/webroot/aapt2"
BLACKLIST_FILE="$MODDIR/webroot/blacklist"

# Architecture Check for AAPT2
ABI=$(getprop ro.product.cpu.abi)
if echo "$ABI" | grep -q "arm64"; then
    AAPT_BIN="aapt2-arm64-v8a"
else
    AAPT_BIN="aapt2-armeabi-v7a"
fi
AAPT="$AAPT_DIR/$AAPT_BIN"
if [ -f "$AAPT" ]; then
    chmod +x "$AAPT"
fi

# === 3. Pre-Processing (Filter Logic) ===
echo "正在初始化..." > "$LOG_FILE"

# Build Skip List
echo -n "" > "$SKIP_FILE"
# 1. Existing results (Don't scan what we already found)
if [ -f "$RESULT_FILE" ]; then
    cat "$RESULT_FILE" >> "$SKIP_FILE"
fi
# 2. Blacklist (Don't scan what user blocked)
if [ -f "$BLACKLIST_FILE" ]; then
    cat "$BLACKLIST_FILE" >> "$SKIP_FILE"
fi
# Deduplicate skip list
sort -u "$SKIP_FILE" -o "$SKIP_FILE"

# Fetch Raw List
echo "正在获取应用列表..." >> "$LOG_FILE"
RAW_LIST=$(pm list packages -f -3)

# Build Target Scan List
echo "正在筛选待扫描应用..." >> "$LOG_FILE"
echo -n "" > "$SCAN_LIST_FILE"

IFS=$'\n'
for line in $RAW_LIST; do
    unset IFS
    [ -z "$line" ] && continue
    
    # Parse line: package:PATH=PKG
    temp=${line#package:}
    apk_path=${temp%=*}
    pkg_name=${temp##*=}
    
    if [ -z "$apk_path" ] || [ -z "$pkg_name" ]; then continue; fi
    
    # Check if in Skip List (Fixed string match)
    if grep -F -x -q "$pkg_name" "$SKIP_FILE"; then
        continue
    fi
    
    # Add to Scan List
    echo "$line" >> "$SCAN_LIST_FILE"
done

# Initialize Counters
TOTAL=$(wc -l < "$SCAN_LIST_FILE")
CURRENT=0
# Note: FOUND is count of *already found* + *newly found*?
# User wants "Found" display. Usually means total valid apps.
# Let's count existing first.
FOUND=0
if [ -f "$RESULT_FILE" ]; then
    FOUND=$(grep -c . "$RESULT_FILE")
fi

echo "开始扫描... (需扫描: $TOTAL, 已收录: $FOUND)" >> "$LOG_FILE"

# If total to scan is 0, we are done
if [ "$TOTAL" -eq 0 ]; then
    echo "{\"total\": 0, \"current\": 0, \"found\": $FOUND, \"pkg\": \"无需扫描\"}" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"
    echo "扫描完成。" >> "$LOG_FILE"
    echo "DONE" >> "$LOG_FILE"
    exit 0
fi

# === 4. Sequential Scan Loop ===
# Iterate over the pre-filtered file
while read -r line; do
    [ -z "$line" ] && continue
    
    temp=${line#package:}
    apk_path=${temp%=*}
    pkg_name=${temp##*=}
    
    CURRENT=$((CURRENT + 1))
    
    # Update Progress (Instant, show current package)
    echo "{\"total\": $TOTAL, \"current\": $CURRENT, \"found\": $FOUND, \"pkg\": \"$pkg_name\"}" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

    # --- Check Logic ---
    # 1. Direct AAPT Check (No unzip)
    output=$("$AAPT" dump badging "$apk_path" 2>/dev/null)
    
    # Robust Icon Extraction
    # Filter for 'application:', then find icon='...'
    icon_path=$(echo "$output" | grep "application:" | sed -n "s/.*icon='\([^']*\)'.*/\1/p" | head -n 1)
    
    if [[ "$icon_path" == *.xml ]]; then
        # 2. XML Tree Deep Check
        # Check for 'monochrome' or 'themed_icon'
        if "$AAPT" dump xmltree "$apk_path" --file "$icon_path" 2>/dev/null | grep -q -i -E "monochrome|themed_icon"; then
            echo "$pkg_name" >> "$RESULT_FILE"
            FOUND=$((FOUND + 1))
            
            # Flush progress immediately on find?
            echo "{\"total\": $TOTAL, \"current\": $CURRENT, \"found\": $FOUND, \"pkg\": \"$pkg_name\"}" > "$PROGRESS_FILE.tmp"
            mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"
        fi
    fi
    
done < "$SCAN_LIST_FILE"

# Final Update
echo "{\"total\": $TOTAL, \"current\": $TOTAL, \"found\": $FOUND, \"pkg\": \"Completed\"}" > "$PROGRESS_FILE.tmp"
mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

echo "扫描完成。" >> "$LOG_FILE"
echo "DONE" >> "$LOG_FILE"
