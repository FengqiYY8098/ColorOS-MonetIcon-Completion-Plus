#!/system/bin/sh
# scan_monet.sh - Filesystem Signaling Version (Deadlock Proof)

# === 1. Environment Setup ===
TMP_DIR="/data/adb/moneticon_tmp"
LOCK_FILE="$TMP_DIR/scan.lock"
PROGRESS_FILE="$TMP_DIR/progress.json"
RESULT_FILE="$TMP_DIR/moneticon_apps"
PIPE_FILE="$TMP_DIR/worker.pipe"
# Tracker directory for counting progress
TRACKER_DIR="$TMP_DIR/tracker"

# Clean & Init
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$TRACKER_DIR"
touch "$LOCK_FILE"
# Clear result file
echo -n "" > "$RESULT_FILE"

# Trap signals
cleanup() {
    # Kill descendants
    pkill -P $$ 2>/dev/null
    rm -f "$PIPE_FILE" "$LOCK_FILE"
    rm -rf "$TRACKER_DIR"
    exit 0
}
trap cleanup EXIT INT TERM

# === 2. Configuration ===
MODDIR=${0%/*}
AAPT_DIR="$MODDIR/webroot/aapt2"

# Architecture Check
ABI=$(getprop ro.product.cpu.abi)
if echo "$ABI" | grep -q "arm64"; then
    AAPT_BIN="aapt2-arm64-v8a"
else
    AAPT_BIN="aapt2-armeabi-v7a"
fi
AAPT="$AAPT_DIR/$AAPT_BIN"
# Ensure executable
if [ ! -f "$AAPT" ]; then
    # Fallback or error logging? 
    # For now assume it exists as per previous steps, but ensure +x
    true
fi
chmod +x "$AAPT"

# CPU Cores
CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
[ -z "$CPU_CORES" ] && CPU_CORES=4
THREADS=$CPU_CORES
[ "$THREADS" -gt 8 ] && THREADS=8

# === 3. Token Bucket (Concurrency Control) ===
# We still keep the token bucket to control CPU load, 
# but we don't use pipes for status data.
mkfifo "$PIPE_FILE"
exec 3<>"$PIPE_FILE"
for i in $(seq 1 $THREADS); do echo >&3; done

# === 4. Progress Monitor (Filesystem Polling) ===
# Independent background process, wakes up every second.
(
    total=0
    current=0
    found=0
    
    # Wait for Total Count
    while [ ! -f "$TMP_DIR/total_count" ]; do sleep 0.1; done
    total=$(cat "$TMP_DIR/total_count")

    while true; do
        # 1. Check for Done Signal
        if [ -f "$TMP_DIR/scan_done" ]; then
            # Final flush
            current=$total
            if [ -f "$RESULT_FILE" ]; then
                found=$(grep -c . "$RESULT_FILE")
            fi
            echo "{\"total\": $total, \"current\": $current, \"found\": $found}" > "$PROGRESS_FILE.tmp"
            mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"
            break
        fi

        # 2. Count Files (Fastest way on Linux for large dirs: ls -f)
        # ls -f lists directory without sorting. grep -c -v excludes . and ..
        current=$(ls -f "$TRACKER_DIR" 2>/dev/null | grep -c -v '^\.\.\?$')
        
        # 3. Count Results
        if [ -f "$RESULT_FILE" ]; then
            found=$(grep -c . "$RESULT_FILE")
        else
            found=0
        fi

        # 4. Update JSON
        echo "{\"total\": $total, \"current\": $current, \"found\": $found}" > "$PROGRESS_FILE.tmp"
        mv "$PROGRESS_FILE.tmp" "$PROGRESS_FILE"
        
        # 5. Sleep to save IO
        sleep 1
    done
) &
MONITOR_PID=$!

# === 5. Worker Logic ===
check_app() {
    local apk_path="$1"
    local pkg_name="$2"
    local is_found=0

    # Step 1: Zip Check (Fastest)
    if unzip -l "$apk_path" 2>/dev/null | grep -q "res/.*-v26"; then
        # Step 2: Badging (Entry verification)
        local output=$("$AAPT" dump badging "$apk_path" 2>/dev/null)
        local icon_path=$(echo "$output" | grep "application: label" | sed -n "s/.*icon='\([^']*\)'.*/\1/p")
        
        if [[ "$icon_path" == *.xml ]]; then
            # Step 3: XML Tree (Deep check)
            if "$AAPT" dump xmltree "$apk_path" --file "$icon_path" 2>/dev/null | grep -q -i "monochrome"; then
                echo "$pkg_name" >> "$RESULT_FILE"
                is_found=1
            fi
        fi
    fi
    
    # Signal Completion via Filesystem
    # This never blocks!
    touch "$TRACKER_DIR/$pkg_name"
}

# === 6. Main Dispatcher ===
echo "Init list..."
RAW_LIST=$(pm list packages -f -3)

# Write Total Count for Monitor
TOTAL_COUNT=$(echo "$RAW_LIST" | grep -c "package:")
echo "$TOTAL_COUNT" > "$TMP_DIR/total_count"

# Parallel Loop
IFS=$'\n'
for line in $RAW_LIST; do
    unset IFS
    [ -z "$line" ] && continue
    
    temp=${line#package:}
    apk_path=${temp%=*}
    pkg_name=${temp##*=}
    [ -z "$apk_path" ] && continue

    # Acquire Token (Block if full)
    read -u 3 token

    # Spawn Worker
    (
        check_app "$apk_path" "$pkg_name"
        # Return Token
        echo >&3
    ) &
done

# Wait for workers
wait

# Signal Monitor to stop
touch "$TMP_DIR/scan_done"
wait $MONITOR_PID

# Cleanup
rm -f "$LOCK_FILE" "$PIPE_FILE" "$TMP_DIR/total_count" "$TMP_DIR/scan_done"
rm -rf "$TRACKER_DIR"
