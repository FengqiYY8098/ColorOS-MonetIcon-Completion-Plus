#!/system/bin/sh
# scan_monet.sh - Sequential Incremental Scanner (Optimized)

# === 1. Environment Setup ===
TMP_DIR="/data/adb/moneticon_tmp"
PROGRESS_FILE="$TMP_DIR/progress.json"
RESULT_FILE="$TMP_DIR/moneticon_apps"
SKIP_FILE="$TMP_DIR/skip_list.txt"
FILTERED_LIST="$TMP_DIR/target_list.txt"
LOG_FILE="$TMP_DIR/scan.log"

# Clean & Init
mkdir -p "$TMP_DIR"
rm -f "$PROGRESS_FILE" "$SKIP_FILE" "$FILTERED_LIST"

trap "rm -f $PROGRESS_FILE $SKIP_FILE $FILTERED_LIST; exit 0" EXIT INT TERM

# === 2. Configuration ===
MODDIR=${0%/*}
AAPT_DIR="$MODDIR/webroot/aapt2"
BLACKLIST_FILE="$MODDIR/webroot/blacklist"

# Architecture Check
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

# === 3. Filter Target List (CORE OPTIMIZATION) ===
echo "Initializing..." > "$LOG_FILE"
echo -n "" > "$SKIP_FILE"

# Consolidate Skip List (Result + Blacklist)
if [ -f "$RESULT_FILE" ]; then cat "$RESULT_FILE" >> "$SKIP_FILE"; fi
if [ -f "$BLACKLIST_FILE" ]; then cat "$BLACKLIST_FILE" >> "$SKIP_FILE"; fi
sort -u "$SKIP_FILE" -o "$SKIP_FILE"

# Get Raw List
# Format: package:/data/.../base.apk=com.pkg
RAW_LIST_STR=$(pm list packages -f -3)

# Since grep -f needs a file compared to a file, let's process RAW_LIST line by line?
# No, "grep -v -f SKIP_FILE" on the package names extracted from RAW_LIST is better.
# But RAW_LIST has full paths.
# Strategy: 
# 1. Parse RAW_LIST to "$path $pkg" format in a temp file.
# 2. Filter this temp file against SKIP_FILE.

echo "$RAW_LIST_STR" | sed 's/^package://; s/=/ /' > "$TMP_DIR/raw_parsed.txt"

# Filter: Retain lines where the 2nd column (pkg) is NOT in SKIP_FILE
# awk is robust for this.
awk 'NR==FNR {skip[$1]=1; next} !($2 in skip) {print $1, $2}' "$SKIP_FILE" "$TMP_DIR/raw_parsed.txt" > "$FILTERED_LIST"

# Initialize Counters
TOTAL_TARGETS=$(wc -l < "$FILTERED_LIST")
CURRENT=0
FOUND=0
if [ -f "$RESULT_FILE" ]; then
    FOUND=$(grep -c . "$RESULT_FILE")
fi

echo "Start Scanning ($TOTAL_TARGETS new apps)..." > "$LOG_FILE"

# === 4. Sequential Scan Loop ===
# Read line by line from FILTERED_LIST (path pkg)
while read -r apk_path pkg_name; do 
    # Skip empty/malformed
    [ -z "$apk_path" ] || [ -z "$pkg_name" ] && continue

    CURRENT=$((CURRENT + 1))
    
    # 1. Direct AAPT Check (No unzip pre-check)
    output=$("$AAPT" dump badging "$apk_path" 2>/dev/null)
    
    # Robust icon path extraction (filter line first, then extract)
    # This handles cases where badging output format might vary
    icon_path=$(echo "$output" | grep "application:" | sed -n "s/.*icon='\([^']*\)'.*/\1/p" | head -n 1)
    
    # Debug Logging
    echo "[DEBUG] Check: $pkg_name | Icon: $icon_path" >> "$LOG_FILE"

    if [[ "$icon_path" == *.xml ]]; then
        # 2. XML Tree Deep Check
        # Check for 'monochrome' OR 'themed_icon'
        xml_check=$("$AAPT" dump xmltree "$apk_path" --file "$icon_path" 2>/dev/null | grep -i -E "monochrome|themed_icon")
        
        if [ -n "$xml_check" ]; then
            echo "$pkg_name" >> "$RESULT_FILE"
            FOUND=$((FOUND + 1))
            echo "[DEBUG] Found: $pkg_name" >> "$LOG_FILE"
        fi
    fi
    
    # Update Progress (Real-time)
    echo "{\"total\": $TOTAL_TARGETS, \"current\": $CURRENT, \"found\": $FOUND, \"pkg\": \"$pkg_name\"}" > "$PROGRESS_FILE.tmp"
    mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

done < "$FILTERED_LIST"

# Final Update
echo "{\"total\": $TOTAL_TARGETS, \"current\": $TOTAL_TARGETS, \"found\": $FOUND, \"pkg\": \"Completed\"}" > "$PROGRESS_FILE.tmp"
mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"

echo "扫描完成。" >> "$LOG_FILE"
echo "DONE" >> "$LOG_FILE"

rm -f "$FILTERED_LIST" "$TMP_DIR/raw_parsed.txt"
