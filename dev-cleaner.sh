#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# 🚀 Dev Cleanup Utility 🧹
# -----------------------------------------------------------------------------

# --- Colors for pretty printing ---
if [ -t 1 ]; then
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    MAGENTA="\033[0;35m"
    NC="\033[0m"
    BOLD="\033[1m"
    FAINT="\033[2m"
else
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    NC=""
    BOLD=""
    FAINT=""
fi

# --- Global Variables ---
SCRIPT_VERSION="1.3.0"
GITHUB_REPO="https://github.com/jemishavasoya/dev-cleaner"
DRY_RUN=false

# Check if FLUTTER_SEARCH_DIR is already set as environment variable
if [ -z "${FLUTTER_SEARCH_DIR}" ]; then
    FLUTTER_SEARCH_DIR="."  # Default search directory for Flutter cleanup
    FLUTTER_DIR_SOURCE="default"
else
    # Expand ~ to home directory if present in environment variable
    FLUTTER_SEARCH_DIR="${FLUTTER_SEARCH_DIR/#\~/$HOME}"
    FLUTTER_DIR_SOURCE="environment"
    
    # Validate environment variable directory
    if [ ! -d "$FLUTTER_SEARCH_DIR" ]; then
        echo -e "${YELLOW}Warning: FLUTTER_SEARCH_DIR environment variable points to non-existent directory: ${FLUTTER_SEARCH_DIR}${NC}"
        echo -e "${YELLOW}Falling back to current directory.${NC}"
        FLUTTER_SEARCH_DIR="."
        FLUTTER_DIR_SOURCE="default"
    fi
fi

# Logo
print_logo() {
    echo -e "${CYAN}${BOLD}"
    # Using 'cat << "EOF"' with no leading space on the logo lines ensures perfect alignment.
    cat << "EOF"
██████╗ ███████╗██╗    ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗███████╗██████╗
██╔══██╗██╔════╝██║    ██║    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██╔════╝██╔══██╗
██║  ██║█████╗  ██║    ██║    ██║     ██║     █████╗  ███████║██╔██╗ ██║█████╗  ██████╔╝
██║  ██║██╔══╝  ╚██╗ ██╔╝     ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██╔══╝  ██╔══██╗
██████╔╝███████╗ ╚████╔╝      ╚██████╗███████╗███████╗██║  ██║██║ ╚████║███████╗██║  ██║
╚═════╝ ╚══════╝  ╚═══╝        ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
}

# --- Helper Functions ---
print_header_line() {
    local char="${1:-─}"
    printf "%$(tput cols)s\n" "" | tr " " "$char"
}

print_section_header() {
    echo -e "${BLUE}${BOLD}➤ $1${NC}"
    print_header_line "─"
}

print_item() {
    local icon="${1}"
    local color="${2}"
    local text="${3}"
    echo -e "${color}${icon} ${text}${NC}"
}

get_disk_space() {
    df -h . | awk 'NR==2 {print $4}'
}

get_disk_space_bytes() {
    df -k . | awk 'NR==2 {print $4}'
}

format_freed_space() {
    local kb_diff=$1
    if [ "$kb_diff" -le 0 ] 2>/dev/null; then
        echo "0 KB"
    elif [ "$kb_diff" -ge 1048576 ]; then
        echo "$(( kb_diff / 1048576 )) GB"
    elif [ "$kb_diff" -ge 1024 ]; then
        echo "$(( kb_diff / 1024 )) MB"
    else
        echo "${kb_diff} KB"
    fi
}

run_with_space_tracking() {
    local label="$1"
    shift
    local before
    before=$(get_disk_space_bytes)
    "$@"
    local after
    after=$(get_disk_space_bytes)
    local freed=$(( after - before ))
    if [ "$freed" -gt 0 ] 2>/dev/null; then
        local formatted
        formatted=$(format_freed_space "$freed")
        echo -e "${MAGENTA}    ↳ Freed: ${formatted}${NC}"
    fi
}

# Dry-run aware file/directory removal
# Usage: safe_rm [-r] <path> [<path> ...]
safe_rm() {
    local recursive=""
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|-rf|-fr)
                recursive="-rf"
                shift
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    for path in "${paths[@]}"; do
        # Expand globs and handle paths
        local expanded_paths=()
        # Use nullglob to handle non-matching patterns
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob
        
        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]]; then
                if $DRY_RUN; then
                    local size=""
                    if [[ -d "$expanded_path" ]]; then
                        size=$(du -sh "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete directory: ${expanded_path} (${size:-unknown size})${NC}"
                    else
                        size=$(du -h "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete file: ${expanded_path} (${size:-unknown size})${NC}"
                    fi
                else
                    if [[ -n "$recursive" ]]; then
                        rm -rf "$expanded_path"
                    else
                        rm -f "$expanded_path"
                    fi
                fi
            fi
        done
    done
}

# Dry-run aware sudo file/directory removal
# Usage: safe_sudo_rm [-r] <path> [<path> ...]
safe_sudo_rm() {
    local recursive=""
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|-rf|-fr)
                recursive="-rf"
                shift
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    for path in "${paths[@]}"; do
        # Expand globs and handle paths
        local expanded_paths=()
        shopt -s nullglob
        if [[ "$path" == *\** || "$path" == *\?* ]]; then
            expanded_paths=($path)
        else
            expanded_paths=("$path")
        fi
        shopt -u nullglob
        
        for expanded_path in "${expanded_paths[@]}"; do
            if [[ -e "$expanded_path" ]] || sudo test -e "$expanded_path" 2>/dev/null; then
                if $DRY_RUN; then
                    local size=""
                    if [[ -d "$expanded_path" ]] || sudo test -d "$expanded_path" 2>/dev/null; then
                        size=$(sudo du -sh "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete directory (sudo): ${expanded_path} (${size:-unknown size})${NC}"
                    else
                        size=$(sudo du -h "$expanded_path" 2>/dev/null | cut -f1)
                        echo -e "${YELLOW}[DRY-RUN] Would delete file (sudo): ${expanded_path} (${size:-unknown size})${NC}"
                    fi
                else
                    if [[ -n "$recursive" ]]; then
                        sudo rm -rf "$expanded_path"
                    else
                        sudo rm -f "$expanded_path"
                    fi
                fi
            fi
        done
    done
}

# --- Cleanup Functions ---
cleanup_xcode() {
    print_item "✓" "${GREEN}" "Clearing Xcode DerivedData..."
    safe_rm -rf ~/Library/Developer/Xcode/DerivedData/
    print_item "✓" "${GREEN}" "Removing old Simulator devices..."
    safe_rm -rf ~/Library/Developer/CoreSimulator/Devices/
    print_item "✓" "${GREEN}" "Removing old device support files..."
    safe_rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/
    print_item "✓" "${GREEN}" "Removing Xcode caches..."
    safe_rm -rf ~/Library/Caches/com.apple.dt.Xcode/
    print_item "✓" "${GREEN}" "Removing Xcode Archives..."
    safe_rm -rf ~/Library/Developer/Xcode/Archives/
    print_item "✓" "${GREEN}" "Removing Xcode build Products..."
    safe_rm -rf ~/Library/Developer/Xcode/Products/
    print_item "✓" "${GREEN}" "Removing Xcode DocumentationCache..."
    safe_rm -rf ~/Library/Developer/Xcode/DocumentationCache/
    print_item "✓" "${GREEN}" "Cleaning CoreDevice cache..."
    safe_rm -rf ~/Library/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches/*
}

cleanup_android() {
    if [ -d "$HOME/.gradle" ]; then
        print_item "✓" "${GREEN}" "Cleaning Gradle caches..."
        safe_rm -rf ~/.gradle/caches/
        safe_rm -rf ~/.gradle/daemon/
    else
        print_item "✕" "${YELLOW}" "Gradle directory not found. Skipping."
    fi
    print_item "✓" "${GREEN}" "Cleaning Android Studio caches..."
    safe_rm -rf ~/Library/Caches/Google/AndroidStudio*
    safe_rm -rf ~/Library/Caches/JetBrains/AndroidStudio*
}

cleanup_android_sdk() {
    if [ -d "$HOME/Library/Android/sdk" ]; then
        print_item "✓" "${GREEN}" "Cleaning old Android SDK build-tools (keeping latest 2 versions)..."
        # Keep only latest 2 versions of build-tools
        if [ -d "$HOME/Library/Android/sdk/build-tools" ]; then
            (
                cd "$HOME/Library/Android/sdk/build-tools" 2>/dev/null || exit 1
                if $DRY_RUN; then
                    ls -t | tail -n +3 | while read -r dir; do
                        echo -e "${YELLOW}[DRY-RUN] Would delete: $HOME/Library/Android/sdk/build-tools/$dir${NC}"
                    done
                else
                    ls -t | tail -n +3 | xargs -I {} rm -rf {}
                fi
            )
        fi

        print_item "✓" "${GREEN}" "Cleaning old Android platform-tools..."
        safe_rm -rf ~/Library/Android/sdk/.temp

        # For Apple Silicon Macs, remove x86 emulator images if they exist
        if [ "$(uname -m)" = "arm64" ]; then
            print_item "✓" "${GREEN}" "Removing x86 emulator images (ARM Mac detected)..."
            if $DRY_RUN; then
                find ~/Library/Android/sdk/system-images -type d -name "x86" 2>/dev/null | while read -r dir; do
                    echo -e "${YELLOW}[DRY-RUN] Would delete: $dir${NC}"
                done
            else
                find ~/Library/Android/sdk/system-images -type d -name "x86" -exec rm -rf {} + 2>/dev/null || true
            fi
        fi
    else
        print_item "✕" "${YELLOW}" "Android SDK not found. Skipping."
    fi
}

cleanup_flutter() {
    local search_dir="${1:-.}"  # Directory to search, current by default
    
    if command -v flutter &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Flutter projects recursively from: $search_dir"
        
        # Validate that the directory exists
        if [ ! -d "$search_dir" ]; then
            print_item "✕" "${RED}" "Directory not found: $search_dir"
            return 1
        fi
        
        # Find all pubspec.yaml files recursively and clean each project
        local cleaned_count=0
        local original_dir
        original_dir=$(pwd)
        while IFS= read -r -d '' pubspec; do
            project_dir=$(cd "$(dirname "$pubspec")" 2>/dev/null && pwd)
            if [ -z "$project_dir" ]; then
                continue
            fi
            
            echo -e "${CYAN}  🧹 Cleaning: $project_dir${NC}"
            
            cd "$project_dir" 2>/dev/null || { 
                print_item "⚠️" "${YELLOW}" "Skipped (can't access $project_dir)"
                continue
            }
            
            # --- 1. FVM destroy ---
            if [ -d ".fvm" ]; then
                echo -e "${FAINT}    🔥 Destroying FVM SDK cache...${NC}"
                yes | fvm destroy >/dev/null 2>&1 || true
            fi
            
            # --- 2. Remove FVM configs ---
            if [ -d ".fvm" ] || [ -f ".fvmrc" ]; then
                echo -e "${FAINT}    🔥 Removing FVM folders...${NC}"
                safe_rm -rf .fvm .fvmrc
            fi
            
            # --- 3. Clean Flutter build & cache dirs ---
            echo -e "${FAINT}    🔥 Removing Flutter build and Pub Dev caches...${NC}"
            safe_rm -rf build .dart_tool .packages pubspec.lock
            
            # --- 4. Clean Gradle caches ---
            if [ -d "android" ]; then
                echo -e "${FAINT}    🔥 Removing Gradle caches...${NC}"
                safe_rm -rf android/.gradle android/build android/app/build
            fi
            
            # --- 5. Clean CocoaPods (iOS) ---
            if [ -d "ios" ]; then
                echo -e "${FAINT}    🔥 Removing CocoaPods caches...${NC}"
                safe_rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/Flutter.framework ios/Flutter/Flutter.podspec
            fi
            
            cleaned_count=$((cleaned_count + 1))
            echo -e "${GREEN}  ✅ Cleaned $project_dir${NC}"
            
            # Restore original directory
            cd "$original_dir" 2>/dev/null || true
        done < <(find "$search_dir" -type f -name "pubspec.yaml" -print0 2>/dev/null)
        
        if [ $cleaned_count -gt 0 ]; then
            print_item "✓" "${GREEN}" "Cleaned $cleaned_count Flutter project(s)"
        else
            print_item "ℹ️" "${YELLOW}" "No Flutter projects found to clean in: $search_dir"
        fi
        
        print_item "✓" "${GREEN}" "Cleaning Flutter global cache..."
        flutter cache clean 2>/dev/null || true
    else
        print_item "✕" "${YELLOW}" "Flutter command not found. Skipping."
    fi
}

cleanup_platformIO() {
    local PIO_BIN="$HOME/.platformio/penv/bin/pio"

    if [ -x "$PIO_BIN" ]; then
        :
    elif command -v pio >/dev/null 2>&1; then
        PIO_BIN="$(command -v pio)"
    else
        print_item "✕" "${YELLOW}" "pio command not found. Skipping."
        return 0
    fi

    print_item "✓" "${GREEN}" "Cleaning PlatformIO project builds (pio run clean)..."

    # Find pubspec.yaml and run 'pio run -t clean' in each directory
    # -print0 handles spaces/newlines safely
    find ~/ -maxdepth 4 -type d -name "Library" -prune -o -name "platformio.ini" -print0 | while IFS= read -r -d '' file; do
        dir="$(dirname "$file")"
        printf 'Running: %s run clean in %s\n' "$PIO_BIN" "$dir"

        # Run in a subshell to avoid changing caller's CWD
        ( cd "$dir" && "$PIO_BIN" run -t clean )
    done
}

cleanup_npm_yarn() {
    if command -v npm &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning npm cache..."
        npm cache clean --force
    else
        print_item "✕" "${YELLOW}" "npm not found. Skipping."
    fi
    if command -v yarn &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning yarn cache..."
        yarn cache clean
    else
        print_item "✕" "${YELLOW}" "yarn not found. Skipping."
    fi
    if command -v pnpm &> /dev/null; then
        print_item "✓" "${GREEN}" "Pruning pnpm store..."
        pnpm store prune
    else
        print_item "✕" "${YELLOW}" "pnpm not found. Skipping."
    fi
}

cleanup_homebrew() {
    if command -v brew &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Homebrew (brew)..."
        brew cleanup
    else
        print_item "✕" "${YELLOW}" "Homebrew not found. Skipping."
    fi
}

cleanup_cocoapods() {
    if [ -d "$HOME/.cocoapods" ]; then
        print_item "✓" "${GREEN}" "Cleaning CocoaPods cache..."
        safe_rm -rf ~/.cocoapods/repos/
        safe_rm -rf ~/Library/Caches/CocoaPods/
    else
        print_item "✕" "${YELLOW}" "CocoaPods not found. Skipping."
    fi
}

cleanup_ide_caches() {
    print_item "✓" "${GREEN}" "Cleaning general JetBrains IDE caches..."
    safe_rm -rf ~/Library/Caches/JetBrains/
    print_item "✓" "${GREEN}" "Cleaning VSCode cache..."
    safe_rm -rf ~/Library/Application\ Support/Code/Cache/
    safe_rm -rf ~/Library/Application\ Support/Code/CachedData/
    safe_rm -rf ~/Library/Application\ Support/Code/User/workspaceStorage/
}

cleanup_system_junk() {
    print_item "✓" "${GREEN}" "Emptying the Trash..."
    safe_sudo_rm -rf ~/.Trash/*
    safe_sudo_rm -rf /Volumes/*/.Trashes/*
    print_item "✓" "${GREEN}" "Cleaning user-level log files..."
    safe_rm -rf ~/Library/Logs/*
    print_item "✓" "${GREEN}" "Cleaning old/rotated system log files..."
    # Only remove rotated/compressed logs, not active ones
    if $DRY_RUN; then
        find /private/var/log -name "*.gz" -o -name "*.bz2" -o -name "*.old" 2>/dev/null | while read -r f; do
            echo -e "${YELLOW}[DRY-RUN] Would delete: $f${NC}"
        done
        find /Library/Logs -name "*.gz" -o -name "*.bz2" -o -name "*.old" 2>/dev/null | while read -r f; do
            echo -e "${YELLOW}[DRY-RUN] Would delete: $f${NC}"
        done
    else
        sudo find /private/var/log -name "*.gz" -o -name "*.bz2" -o -name "*.old" -exec rm -f {} + 2>/dev/null || true
        sudo find /Library/Logs -name "*.gz" -o -name "*.bz2" -o -name "*.old" -exec rm -f {} + 2>/dev/null || true
    fi
}

cleanup_browser_caches() {
    if [ -d "$HOME/Library/Caches/Google/Chrome" ]; then
        print_item "✓" "${GREEN}" "Cleaning Chrome cache..."
        safe_rm -rf ~/Library/Caches/Google/Chrome/*
    else
        print_item "✕" "${YELLOW}" "Chrome cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/BraveSoftware/Brave-Browser" ]; then
        print_item "✓" "${GREEN}" "Cleaning Brave cache..."
        safe_rm -rf ~/Library/Caches/BraveSoftware/Brave-Browser/*
    else
        print_item "✕" "${YELLOW}" "Brave cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Firefox" ]; then
        print_item "✓" "${GREEN}" "Cleaning Firefox cache..."
        safe_rm -rf ~/Library/Caches/Firefox/*
    else
        print_item "✕" "${YELLOW}" "Firefox cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.apple.Safari" ]; then
        print_item "✓" "${GREEN}" "Cleaning Safari cache..."
        safe_rm -rf ~/Library/Caches/com.apple.Safari/*
    else
        print_item "✕" "${YELLOW}" "Safari cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/Microsoft Edge" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        safe_rm -rf ~/Library/Caches/Microsoft\ Edge/*
    elif [ -d "$HOME/Library/Caches/com.microsoft.edgemac" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Edge cache..."
        safe_rm -rf ~/Library/Caches/com.microsoft.edgemac/*
    else
        print_item "✕" "${YELLOW}" "Microsoft Edge cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.Opera" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera cache..."
        safe_rm -rf ~/Library/Caches/com.operasoftware.Opera/*
    else
        print_item "✕" "${YELLOW}" "Opera cache not found. Skipping."
    fi
    if [ -d "$HOME/Library/Caches/com.operasoftware.OperaGX" ]; then
        print_item "✓" "${GREEN}" "Cleaning Opera GX cache..."
        safe_rm -rf ~/Library/Caches/com.operasoftware.OperaGX/*
    fi
}

cleanup_app_containers() {
    print_item "✓" "${GREEN}" "Cleaning app container caches..."

    # Slack
    if [ -d "$HOME/Library/Containers/com.tinyspeck.slackmacgap" ]; then
        print_item "✓" "${GREEN}" "Cleaning Slack cache..."
        safe_rm -rf ~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Caches/*
    fi

    # Microsoft Teams
    if [ -d "$HOME/Library/Containers/com.microsoft.teams2" ]; then
        print_item "✓" "${GREEN}" "Cleaning Microsoft Teams cache..."
        safe_rm -rf ~/Library/Containers/com.microsoft.teams2/Data/Library/Caches/*
    fi

    # WhatsApp
    if [ -d "$HOME/Library/Containers/net.whatsapp.WhatsApp" ]; then
        print_item "✓" "${GREEN}" "Cleaning WhatsApp cache..."
        safe_rm -rf ~/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches/*
    fi

    # Discord
    if [ -d "$HOME/Library/Application Support/discord" ]; then
        print_item "✓" "${GREEN}" "Cleaning Discord cache..."
        safe_rm -rf ~/Library/Application\ Support/discord/Cache/*
        safe_rm -rf ~/Library/Application\ Support/discord/Code\ Cache/*
    fi

    # Spotify
    if [ -d "$HOME/Library/Caches/com.spotify.client" ]; then
        print_item "✓" "${GREEN}" "Cleaning Spotify cache..."
        safe_rm -rf ~/Library/Caches/com.spotify.client/*
    fi
    if [ -d "$HOME/Library/Application Support/Spotify/PersistentCache" ]; then
        safe_rm -rf ~/Library/Application\ Support/Spotify/PersistentCache/*
    fi
}

cleanup_docker() {
    if command -v docker &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning Docker system..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN] Would run: docker system prune -f${NC}"
            echo -e "${YELLOW}[DRY-RUN] Would run: docker builder prune -f${NC}"
            docker system df 2>/dev/null || true
        else
            docker system prune -f 2>/dev/null || true
            docker builder prune -f 2>/dev/null || true
        fi
    else
        print_item "✕" "${YELLOW}" "Docker not found. Skipping."
    fi
}

cleanup_rust() {
    if [ -d "$HOME/.cargo" ]; then
        print_item "✓" "${GREEN}" "Cleaning Rust/Cargo caches..."
        safe_rm -rf ~/.cargo/registry/cache/
        safe_rm -rf ~/.cargo/registry/src/
        safe_rm -rf ~/.cargo/git/checkouts/
    else
        print_item "✕" "${YELLOW}" "Cargo directory not found. Skipping."
    fi
}

cleanup_python() {
    if command -v pip3 &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning pip cache..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN] Would run: pip3 cache purge${NC}"
        else
            pip3 cache purge 2>/dev/null || true
        fi
    elif command -v pip &> /dev/null; then
        print_item "✓" "${GREEN}" "Cleaning pip cache..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN] Would run: pip cache purge${NC}"
        else
            pip cache purge 2>/dev/null || true
        fi
    else
        print_item "✕" "${YELLOW}" "pip not found. Skipping."
    fi
    # Clean __pycache__ and .pyc in home directory (shallow)
    if [ -d "$HOME/.cache/pip" ]; then
        print_item "✓" "${GREEN}" "Removing pip HTTP cache..."
        safe_rm -rf ~/.cache/pip/
    fi
}

check_storage() {
    print_section_header "Storage Usage Report"

    echo -e "${CYAN}📱 iOS Backups:${NC}"
    du -sh ~/Library/Application\ Support/MobileSync/Backup 2>/dev/null || echo "  None found"
    echo ""

    echo -e "${CYAN}🐳 Docker Storage:${NC}"
    docker system df 2>/dev/null || echo "  Docker not installed"
    echo ""

    echo -e "${CYAN}⏰ Time Machine Local Snapshots:${NC}"
    tmutil listlocalsnapshots / 2>/dev/null | wc -l | xargs echo "  Snapshots count:"
    echo ""

    echo -e "${CYAN}📧 Mail Data:${NC}"
    du -sh ~/Library/Mail 2>/dev/null || echo "  None found"
    du -sh ~/Library/Mail\ Downloads 2>/dev/null || echo "  None found"
    echo ""

    echo -e "${CYAN}💿 macOS Installers:${NC}"
    du -sh /Applications/Install\ macOS*.app 2>/dev/null || echo "  None found"
    du -sh ~/Library/Updates 2>/dev/null || echo "  None found"
    echo ""

    echo -e "${CYAN}🎵 Spotify Cache:${NC}"
    du -sh ~/Library/Caches/com.spotify.client 2>/dev/null || echo "  None found"
    echo ""

    echo -e "${CYAN}📦 Largest directories in ~/Library:${NC}"
    du -sh ~/Library/* 2>/dev/null | sort -hr | head -10
}

cleanup_timemachine_snapshots() {
    print_item "✓" "${GREEN}" "Removing Time Machine local snapshots..."

    # List and delete local snapshots
    local snapshot_count=0
    while IFS= read -r snapshot; do
        if [[ "$snapshot" == *"com.apple.TimeMachine"* ]]; then
            local snapshot_date=$(echo "$snapshot" | grep -o '[0-9-]*$')
            if [ -n "$snapshot_date" ]; then
                print_item "✓" "${GREEN}" "Deleting snapshot: $snapshot_date"
                sudo tmutil deletelocalsnapshots "$snapshot_date" 2>/dev/null || true
                snapshot_count=$((snapshot_count + 1))
            fi
        fi
    done < <(sudo tmutil listlocalsnapshots / 2>/dev/null)

    if [ $snapshot_count -eq 0 ]; then
        print_item "ℹ️" "${YELLOW}" "No Time Machine local snapshots found"
    else
        print_item "✓" "${GREEN}" "Deleted $snapshot_count Time Machine snapshot(s)"
    fi
}

# --- Main Display Function ---
display_menu() {
    clear
    local current_free_space=$(get_disk_space)

    print_logo
    echo -e "${FAINT}  Version: v${SCRIPT_VERSION}${NC}" # Display version
    print_item "✨" "${GREEN}" "Free Space: ${current_free_space}"
    echo ""
    print_section_header "Available Options:"
    echo -e "${RED} 0.${NC} ${BOLD}Exit Program${NC}"
    echo -e "${GREEN} 1.${NC} Clear All Caches"
    echo -e "${GREEN} 2.${NC} Clear Xcode Caches & DerivedData"
    echo -e "${GREEN} 3.${NC} Clear Android/Gradle Caches"
    echo -e "${GREEN} 4.${NC} Clear Flutter Caches ${FAINT}(with custom directory option)${NC}"
    echo -e "${GREEN} 5.${NC} Clear npm/Yarn/pnpm Caches"
    echo -e "${GREEN} 6.${NC} Clean Homebrew Caches"
    echo -e "${GREEN} 7.${NC} Clear CocoaPods Caches"
    echo -e "${GREEN} 8.${NC} Clear IDE (JetBrains, VSCode) Caches"
    echo -e "${GREEN} 9.${NC} Clean System Junk & Logs (requires sudo)"
    echo -e "${GREEN}10.${NC} Clear Browser Caches (Chrome, Brave, Firefox, Safari, Edge, Opera)"
    echo -e "${GREEN}11.${NC} Clear PlatformIO Caches"
    echo -e "${GREEN}12.${NC} Clean Android SDK (old build-tools, x86 images)"
    echo -e "${GREEN}13.${NC} Clean App Containers (Slack, Teams, Discord, Spotify, WhatsApp)"
    echo -e "${GREEN}14.${NC} Remove Time Machine Local Snapshots (requires sudo)"
    echo -e "${GREEN}15.${NC} Clean Docker (system prune, builder prune)"
    echo -e "${GREEN}16.${NC} Clean Rust/Cargo Caches"
    echo -e "${GREEN}17.${NC} Clean Python/pip Caches"
    echo -e "${GREEN}18.${NC} Check Storage Usage ${FAINT}(read-only report)${NC}"
    echo ""
    echo -e "→ Please enter your choice (0-18): ${NC}\c"
}

# --- Help function ---
show_help() {
    cat << EOF
Dev Cleanup Utility v${SCRIPT_VERSION}
A powerful cleanup utility for development environments on macOS

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --version           Show version information
  --dry-run               Show what would be deleted without actually removing files
  --flutter-dir PATH      Set custom directory for Flutter cleanup (default: current directory)
                          Example: $0 --flutter-dir ~/Projects

Command-line Flutter cleanup:
  You can specify a custom directory for Flutter cleanup using the --flutter-dir option.
  This directory will be used when running the interactive menu or the "Clear All" option.

Examples:
  $0                                    # Run interactive menu (searches current directory for Flutter projects)
  $0 --dry-run                          # Preview what would be deleted without removing anything
  $0 --flutter-dir ~/Development        # Run with custom Flutter search directory
  $0 --flutter-dir ~/Projects/Flutter   # Search only in specific Flutter projects folder

Repository: ${GITHUB_REPO}
EOF
}

# --- Main Logic ---
main_loop() {
    # Request sudo at the start to cover all options that need it
    echo -e "${YELLOW}This script may require administrator privileges for some cleanup tasks.${NC}"
    echo -e "${YELLOW}You will be prompted to enter your password if needed.${NC}"
    sudo -v
    # Keep sudo session alive in background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_PID=$!

    while true; do
        display_menu
        read -r choice
        echo "" # New line for better separation

        local initial_free_space=$(get_disk_space)

        case "$choice" in
            0)
                echo -e "${GREEN}Exiting cleanup utility. Goodbye!${NC}"
                break
                ;;
            1)
                print_section_header "Performing ALL Cleanup Tasks"
                run_with_space_tracking "Xcode" cleanup_xcode
                run_with_space_tracking "Android/Gradle" cleanup_android
                run_with_space_tracking "Android SDK" cleanup_android_sdk
                run_with_space_tracking "Flutter" cleanup_flutter "$FLUTTER_SEARCH_DIR"
                run_with_space_tracking "PlatformIO" cleanup_platformIO
                run_with_space_tracking "npm/Yarn/pnpm" cleanup_npm_yarn
                run_with_space_tracking "Homebrew" cleanup_homebrew
                run_with_space_tracking "CocoaPods" cleanup_cocoapods
                run_with_space_tracking "IDE Caches" cleanup_ide_caches
                run_with_space_tracking "System Junk" cleanup_system_junk
                run_with_space_tracking "Browser Caches" cleanup_browser_caches
                run_with_space_tracking "App Containers" cleanup_app_containers
                run_with_space_tracking "Time Machine" cleanup_timemachine_snapshots
                run_with_space_tracking "Docker" cleanup_docker
                run_with_space_tracking "Rust/Cargo" cleanup_rust
                run_with_space_tracking "Python/pip" cleanup_python
                ;;
            2)
                print_section_header "Performing Xcode Cleanup"
                run_with_space_tracking "Xcode" cleanup_xcode
                ;;
            3)
                print_section_header "Performing Android/Gradle Cleanup"
                run_with_space_tracking "Android/Gradle" cleanup_android
                ;;
            4)
                print_section_header "Performing Flutter Cleanup"
                echo -e "${CYAN}Current Flutter search directory: ${FLUTTER_SEARCH_DIR}${NC}"
                case "$FLUTTER_DIR_SOURCE" in
                    "environment")
                        echo -e "${FAINT}  (from FLUTTER_SEARCH_DIR environment variable)${NC}"
                        ;;
                    "command-line")
                        echo -e "${FAINT}  (from --flutter-dir command-line argument)${NC}"
                        ;;
                    "default")
                        echo -e "${FAINT}  (default: current directory)${NC}"
                        ;;
                esac
                echo ""
                echo -e "${YELLOW}Enter a custom directory path, or press Enter to use current setting:${NC}"
                read -r custom_flutter_dir
                
                # Use custom directory if provided, otherwise use global setting
                if [ -n "$custom_flutter_dir" ]; then
                    # Expand ~ to home directory
                    custom_flutter_dir="${custom_flutter_dir/#\~/$HOME}"
                    
                    if [ -d "$custom_flutter_dir" ]; then
                        echo -e "${CYAN}Using interactive override: ${custom_flutter_dir}${NC}"
                        cleanup_flutter "$custom_flutter_dir"
                    else
                        print_item "✕" "${RED}" "Directory does not exist: $custom_flutter_dir"
                        case "$FLUTTER_DIR_SOURCE" in
                            "environment")
                                echo -e "${YELLOW}Falling back to environment variable setting: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                            "command-line")
                                echo -e "${YELLOW}Falling back to command-line argument: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                            "default")
                                echo -e "${YELLOW}Falling back to default directory: ${FLUTTER_SEARCH_DIR}${NC}"
                                ;;
                        esac
                        cleanup_flutter "$FLUTTER_SEARCH_DIR"
                    fi
                else
                    cleanup_flutter "$FLUTTER_SEARCH_DIR"
                fi
                ;;
            5)
                print_section_header "Performing npm/Yarn/pnpm Cleanup"
                run_with_space_tracking "npm/Yarn/pnpm" cleanup_npm_yarn
                ;;
            6)
                print_section_header "Performing Homebrew Cleanup"
                run_with_space_tracking "Homebrew" cleanup_homebrew
                ;;
            7)
                print_section_header "Performing CocoaPods Cleanup"
                run_with_space_tracking "CocoaPods" cleanup_cocoapods
                ;;
            8)
                print_section_header "Performing IDE Caches Cleanup"
                run_with_space_tracking "IDE Caches" cleanup_ide_caches
                ;;
            9)
                print_section_header "Performing System Junk & Logs Cleanup"
                run_with_space_tracking "System Junk" cleanup_system_junk
                ;;
            10)
                print_section_header "Performing Browser Caches Cleanup"
                run_with_space_tracking "Browser Caches" cleanup_browser_caches
                ;;
            11)
                print_section_header "Performing PlatformIO Caches cleanup"
                run_with_space_tracking "PlatformIO" cleanup_platformIO
                ;;
            12)
                print_section_header "Performing Android SDK Cleanup"
                run_with_space_tracking "Android SDK" cleanup_android_sdk
                ;;
            13)
                print_section_header "Performing App Containers Cleanup"
                run_with_space_tracking "App Containers" cleanup_app_containers
                ;;
            14)
                print_section_header "Performing Time Machine Snapshots Cleanup"
                run_with_space_tracking "Time Machine" cleanup_timemachine_snapshots
                ;;
            15)
                print_section_header "Performing Docker Cleanup"
                run_with_space_tracking "Docker" cleanup_docker
                ;;
            16)
                print_section_header "Performing Rust/Cargo Cleanup"
                run_with_space_tracking "Rust/Cargo" cleanup_rust
                ;;
            17)
                print_section_header "Performing Python/pip Cleanup"
                run_with_space_tracking "Python/pip" cleanup_python
                ;;
            18)
                check_storage
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter a number between 0 and 18.${NC}"
                sleep 2
                ;;
        esac

        local final_free_space=$(get_disk_space)
        echo ""
        if $DRY_RUN; then
            echo -e "${CYAN}🔍 Dry-run analysis completed!${NC}"
            echo -e "${CYAN}No files were deleted. Run without --dry-run to perform actual cleanup.${NC}"
        else
            echo -e "${GREEN}✅ Cleanup task(s) completed!${NC}"
            echo -e "${BLUE}Disk space before: ${initial_free_space}${NC}"
            echo -e "${BLUE}Disk space after:  ${final_free_space}${NC}"
        fi
        echo ""
        read -p "Press Enter to return to the menu..."
    done

    # Kill the background sudo-keep-alive process
    kill "$SUDO_PID" 2>/dev/null
    echo -e "${GREEN}Cleanup session ended.${NC}"
}

# --- Handle command line arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "Dev Cleaner v${SCRIPT_VERSION}"
            echo "A powerful cleanup utility for development environments"
            echo "Repository: ${GITHUB_REPO}"
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --flutter-dir)
            if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                # Expand ~ to home directory
                FLUTTER_SEARCH_DIR="${2/#\~/$HOME}"
                FLUTTER_DIR_SOURCE="command-line"
                shift 2
            else
                echo -e "${RED}Error: --flutter-dir requires a directory path${NC}"
                echo "Use -h or --help for usage information"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate Flutter search directory if custom one was provided
if [ "$FLUTTER_SEARCH_DIR" != "." ] && [ ! -d "$FLUTTER_SEARCH_DIR" ]; then
    echo -e "${RED}Error: Flutter search directory does not exist: ${FLUTTER_SEARCH_DIR}${NC}"
    echo "Please provide a valid directory path."
    exit 1
fi

# --- Initial check for user confirmation before starting the interactive menu ---
clear
echo -e "${RED}--- 🚀 Dev Cleanup Utility ---${NC}"
if $DRY_RUN; then
    echo -e "${CYAN}${BOLD}🔍 DRY-RUN MODE ENABLED${NC}"
    echo -e "${CYAN}This will show what would be deleted without actually removing any files.${NC}"
else
    echo "This script will permanently delete cache files from your system."
    echo "Review the options carefully before proceeding."
fi
echo ""

# Report Flutter search directory and its source
if [ "$FLUTTER_SEARCH_DIR" != "." ]; then
    echo -e "${CYAN}Flutter search directory: ${FLUTTER_SEARCH_DIR}${NC}"
    case "$FLUTTER_DIR_SOURCE" in
        "environment")
            echo -e "${FAINT}  (set via FLUTTER_SEARCH_DIR environment variable)${NC}"
            ;;
        "command-line")
            echo -e "${FAINT}  (set via --flutter-dir command-line argument)${NC}"
            ;;
    esac
    echo ""
else
    echo -e "${FAINT}Flutter search directory: current directory (default)${NC}"
    echo ""
fi

if $DRY_RUN; then
    echo -e "${GREEN}✓ Safe to run: No files will be modified in dry-run mode.${NC}"
    echo ""
    read -p "Start dry-run analysis? (y/N): " initial_confirm
else
    echo -e "${YELLOW}⚠️ This action is IRREVERSIBLE for deleted files. ⚠️${NC}"
    echo -e "${YELLOW}Please CLOSE all development applications (Xcode, Android Studio, VSCode, etc.) before running.${NC}"
    echo ""
    read -p "Are you sure you want to start the cleanup utility? (y/N): " initial_confirm
fi
if [[ "$initial_confirm" != "y" && "$initial_confirm" != "Y" ]]; then
    echo "Cleanup utility cancelled."
    exit 0
fi

main_loop
