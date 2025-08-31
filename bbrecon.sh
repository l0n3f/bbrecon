#!/usr/bin/env bash

# bbrecon.sh - Bug Bounty Reconnaissance Framework
# Strict bash configuration - but allow for graceful error handling
set -Euo pipefail
IFS=$'\n\t'

# Base configuration
readonly BASE_DIR="/home/l0n3/bugbounty"
readonly SCRIPT_DIR="/home/l0n3/bbrecon"

# Global variables
TARGET=""
TARGET_DIR=""
LOG_FILE=""
TELEGRAM_ENABLED=true

# Load utilities
source "${SCRIPT_DIR}/utils/telegram.sh"
source "${SCRIPT_DIR}/utils/report_generator.sh"

#######################################
# Banner display
#######################################

show_banner() {
    echo "██████╗ ██████╗ ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗"
    echo "██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║"
    echo "██████╔╝██████╔╝██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║"
    echo "██╔══██╗██╔══██╗██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║"
    echo "██████╔╝██████╔╝██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║"
    echo "╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo "================================================================"
    echo "     Bug Bounty Reconnaissance Framework | Created by d0x"
    echo "    Stealth Mode | Rate Limited | Secure | JS Secret Hunter"
    echo "================================================================"
    echo ""
}

show_help() {
    show_banner
    echo "USAGE:"
    echo "  bbrecon [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -t, --target TARGET    Specify target domain directly"
    echo "  --no-telegram         Disable Telegram notifications"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  bbrecon -t example.com"
    echo "  bbrecon --target example.com --no-telegram"
    echo "  bbrecon"
    echo ""
    echo "FEATURES:"
    echo "  • Subdomain enumeration with subfinder + httpx"
    echo "  • JavaScript file discovery with katana + gau"
    echo "  • Secret detection (Firebase, AWS, GitHub, Stripe...)"
    echo "  • URL extraction from JS files"
    echo "  • HTML reports with dark mode"
    echo "  • Telegram notifications"
    echo "  • Rate limiting for stealth reconnaissance"
    echo ""
}

#######################################
# Logging functions
#######################################

timestamp() {
    date '+%Y%m%d_%H%M%S'
}

log_info() {
    local message="$1"
    local timestamp_str="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[INFO] ${timestamp_str} - ${message}" | tee -a "${LOG_FILE:-/dev/null}"
}

log_warn() {
    local message="$1"
    local timestamp_str="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[WARN] ${timestamp_str} - ${message}" | tee -a "${LOG_FILE:-/dev/null}"
}

log_error() {
    local message="$1"
    local timestamp_str="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[ERROR] ${timestamp_str} - ${message}" >&2 | tee -a "${LOG_FILE:-/dev/null}"
}

#######################################
# Error handling
#######################################

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script terminated unexpectedly with code: $exit_code"
        if [[ -n "${TARGET:-}" ]]; then
            send_message "❌ Error in bbrecon for \`${TARGET}\` - Code: $exit_code"
        fi
    fi
    exit $exit_code
}

trap cleanup ERR EXIT

#######################################
# Utility functions
#######################################

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Directory created: $dir"
    fi
}

notify_module_done() {
    local module_name="$1"
    local file_path="$2"
    
    if [[ -f "$file_path" && -s "$file_path" ]]; then
        local lines
        lines=$(wc -l < "$file_path" 2>/dev/null || echo 0)
        local filename
        filename=$(basename "$file_path")
        send_message "✅ \`${module_name}\` completed for \`${TARGET}\` - ${lines} lines in ${filename}"
    else
        send_message "⚠️ \`${module_name}\` completed for \`${TARGET}\` (no output)"
    fi
}

#######################################
# Configuration loading
#######################################

load_config() {
    local env_file="${SCRIPT_DIR}/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Configuration file not found: $env_file"
        echo "Error: .env file not found at $env_file"
        echo "Copy env.example to .env and configure the necessary variables."
        exit 1
    fi
    
    # Load variables from .env
    set -a
    source "$env_file"
    set +a
    
    log_info "Configuration loaded from $env_file"
}

#######################################
# Target validation
#######################################

validate_target() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Target cannot be empty"
        return 1
    fi
    
    if [[ "$target" =~ [[:space:]] ]]; then
        log_error "Target cannot contain spaces"
        return 1
    fi
    
    # Convert to lowercase
    TARGET="${target,,}"
    TARGET_DIR="${BASE_DIR}/${TARGET}"
    
    log_info "Target validated: $TARGET"
    return 0
}

#######################################
# Target directory handling
#######################################

handle_existing_target_dir() {
    if [[ ! -d "$TARGET_DIR" ]]; then
        return 0
    fi
    
    echo "Directory $TARGET_DIR already exists."
    echo "Options:"
    echo "1) Overwrite (move existing to backup)"
    echo "2) Append (keep existing files)"
    echo "3) Cancel"
    
    local choice
    read -r -p "Select an option [1-3]: " choice
    
    case "$choice" in
        1)
            local backup_dir="${TARGET_DIR}.backup-$(timestamp)"
            log_info "Moving $TARGET_DIR to $backup_dir"
            mv "$TARGET_DIR" "$backup_dir"
            ;;
        2)
            log_info "Appending to existing directory: $TARGET_DIR"
            ;;
        3)
            log_info "Operation cancelled by user"
            exit 0
            ;;
        *)
            log_error "Invalid option: $choice"
            exit 1
            ;;
    esac
}

#######################################
# JavaScript analysis with gau and wget
#######################################

run_js_crawling() {
    log_info "Starting JavaScript crawling phase"
    
    echo "[+] ==> JAVASCRIPT CRAWLING PHASE: Finding Alive JS Files"
    
    # Initialize the final alive JS files list
    local alive_js_files="${TARGET_DIR}/alive_js_files.txt"
    : > "$alive_js_files"
    
    # Step 1: JS file discovery with katana (from alive subdomains) + httpx verification
    echo "[+] Phase 1: Crawling for JS files with katana and verifying aliveness..."
    if [[ -f "${TARGET_DIR}/alive_subs.txt" && -s "${TARGET_DIR}/alive_subs.txt" ]]; then
        # Use timeout to prevent hanging and better error handling
        timeout 300 cat "${TARGET_DIR}/alive_subs.txt" | katana -depth 3 -c 2 -delay 2 2>/dev/null | grep -E "\.(js|jsx)(\?|$)" 2>/dev/null | grep -v -E "\.(json|css|png|jpg|gif|svg|woff|ttf)(\?|$)" 2>/dev/null | httpx -mc 200 -silent 2>/dev/null >> "$alive_js_files" 2>/dev/null || echo "[-] Katana/JS discovery failed"
        
        local katana_count=$(wc -l < "$alive_js_files" 2>/dev/null || echo 0)
        echo "[+] Found $katana_count alive JavaScript files with katana"
    else
        echo "[-] No alive subdomains to crawl"
    fi
    
    # Step 2: Find JS files using gau (historical/archived) + httpx verification
    echo "[+] Phase 2: Finding JavaScript files with gau and verifying aliveness..."
    local temp_gau="${TARGET_DIR}/temp_gau_js.txt"
    timeout 120 gau --threads 2 "$TARGET" 2>/dev/null | grep -E "\.(js|jsx)(\?|$)" 2>/dev/null | grep -v -E "\.(json|css|png|jpg|gif|svg|woff|ttf)(\?|$)" 2>/dev/null | sort -u > "$temp_gau" 2>/dev/null || echo "[-] Gau failed to find JS files"
    
    if [[ -f "$temp_gau" && -s "$temp_gau" ]]; then
        local gau_raw_count=$(wc -l < "$temp_gau")
        echo "[+] Found $gau_raw_count raw JavaScript files with gau"
        
        # Verify aliveness with httpx and append to final list
        cat "$temp_gau" | httpx -mc 200 -silent 2>/dev/null >> "$alive_js_files" 2>/dev/null || echo "[-] Gau httpx verification failed"
        
        # Clean up temporary file
        rm -f "$temp_gau"
    else
        echo "[-] No JavaScript files found with gau"
    fi
    
    # Step 3: Remove duplicates from final list
    echo "[+] Phase 3: Finalizing unique alive JavaScript files..."
    if [[ -f "$alive_js_files" && -s "$alive_js_files" ]]; then
        sort -u -o "$alive_js_files" "$alive_js_files" 2>/dev/null || true
        local total_alive_count=$(wc -l < "$alive_js_files")
        echo "[+] Final result: $total_alive_count unique alive JavaScript files"
    else
        echo "[-] No alive JavaScript files found"
        touch "$alive_js_files"
    fi
    
    log_info "JavaScript crawling completed"
    notify_module_done "js_crawling" "$alive_js_files"
}

#######################################
# JavaScript analysis with wget
#######################################

run_js_analysis() {
    log_info "Starting JavaScript analysis with wget"
    
    echo "[+] ==> JAVASCRIPT ANALYSIS PHASE: Deep Analysis of JS Files"
    
    # Use the alive JS files directly from the crawling phase
    local alive_js_files="${TARGET_DIR}/alive_js_files.txt"
    
    if [[ ! -f "$alive_js_files" ]]; then
        echo "[-] No alive JavaScript files found from crawling phase"
        touch "$alive_js_files"
    fi
    
    # Step 2: Download alive JS files
    echo "[+] Phase 2: Downloading alive JavaScript files..."
    local js_downloads_dir="${TARGET_DIR}/js_downloads"
    mkdir -p "$js_downloads_dir"
    
    local downloaded_count=0
    local failed_count=0
    
    if [[ -f "$alive_js_files" && -s "$alive_js_files" ]]; then
        # Download all alive JavaScript files
        echo "[+] Starting download of $(wc -l < "$alive_js_files") JavaScript files..."
        while read url; do 
            echo "[+] Downloading: $url"
            wget -q --timeout=45 --tries=3 --no-check-certificate "$url" -P "$js_downloads_dir/" 2>/dev/null && echo "[+] Success" || echo "[-] Failed"
        done < "$alive_js_files"
        echo "[+] Download process completed"
        
        # Step 3: Extract URLs from downloaded JS files
        echo "[+] Phase 3: Extracting URLs from JavaScript files..."
        local extracted_urls="${TARGET_DIR}/extracted_urls.txt"
        : > "$extracted_urls"
        
        if [[ -d "$js_downloads_dir" ]]; then
            # Find all JS files and extract URLs
            find "$js_downloads_dir" -name "*.js" -type f 2>/dev/null | while read -r js_file; do
                echo "[+] Analyzing: $(basename "$js_file")"
                grep -Eo "(https?://[a-zA-Z0-9\.\/\-\_]+)" "$js_file" 2>/dev/null >> "$extracted_urls" || true
            done
            
            # Remove duplicates and count
            if [[ -f "$extracted_urls" ]]; then
                sort -u -o "$extracted_urls" "$extracted_urls" 2>/dev/null || true
                local urls_count=$(wc -l < "$extracted_urls" 2>/dev/null || echo 0)
                echo "[+] Extracted $urls_count unique URLs from JavaScript files"
            else
                echo "[-] No URLs extracted"
                touch "$extracted_urls"
            fi
        fi
        
        # Step 4: Search for secrets in JS files
        echo "[+] Phase 4: Searching for secrets in JavaScript files..."
        local secrets_found="${TARGET_DIR}/js_secrets.txt"
        : > "$secrets_found"
        
        if [[ -f "$alive_js_files" ]]; then
            echo "[+] Searching for secrets in JavaScript files..."
            
            while IFS= read -r js_url; do
                if [[ -n "$js_url" ]]; then
                    echo "[+] Analyzing: $js_url"
                    
                    # Get filename from URL for reference
                    js_filename=$(basename "$js_url" | cut -d'?' -f1)
                    
                    # Download and search for secrets in one go (with rate limiting)
                    timeout 30 curl -s -k "$js_url" 2>/dev/null | {
                        # Extract Firebase API keys
                        grep -Eho "AIza[A-Za-z0-9_-]{35}" | while read -r secret; do
                            echo "[FIREBASE] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract Stripe keys
                        grep -Eho "sk_[A-Za-z0-9]{48}" | while read -r secret; do
                            echo "[STRIPE_SECRET] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        grep -Eho "pk_[A-Za-z0-9]{48}" | while read -r secret; do
                            echo "[STRIPE_PUBLIC] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract GitHub tokens
                        grep -Eho "ghp_[A-Za-z0-9]{36}" | while read -r secret; do
                            echo "[GITHUB_TOKEN] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        grep -Eho "gho_[A-Za-z0-9]{36}" | while read -r secret; do
                            echo "[GITHUB_OAUTH] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract Slack tokens
                        grep -Eho "xoxb-[A-Za-z0-9-]+" | while read -r secret; do
                            echo "[SLACK_BOT] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        grep -Eho "xoxp-[A-Za-z0-9-]+" | while read -r secret; do
                            echo "[SLACK_USER] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract AWS keys
                        grep -Eho "AKIA[0-9A-Z]{16,20}" | while read -r secret; do
                            echo "[AWS_ACCESS_KEY] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        grep -Eho "ASIA[0-9A-Z]{16,20}" | while read -r secret; do
                            echo "[AWS_SESSION_TOKEN] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract Google OAuth tokens
                        grep -Eho "ya29\.[0-9A-Za-z_-]+" | while read -r secret; do
                            echo "[GOOGLE_OAUTH] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        # Extract generic API patterns with context
                        grep -Eho "api_key[\"']*[=:][\"']*[A-Za-z0-9_-]{20,}" | while read -r secret; do
                            echo "[API_KEY] [$js_filename] $secret" >> "$secrets_found"
                        done
                        
                        grep -Eho "apikey[\"']*[=:][\"']*[A-Za-z0-9_-]{20,}" | while read -r secret; do
                            echo "[API_KEY] [$js_filename] $secret" >> "$secrets_found"
                        done
                    } 2>/dev/null || true
                    
                    # Rate limiting: 3 second delay between file downloads
                    sleep 3
                fi
            done < "$alive_js_files"
            
            # Remove duplicates and clean up
            if [[ -f "$secrets_found" ]]; then
                sort -u -o "$secrets_found" "$secrets_found" 2>/dev/null || true
                local secrets_count=$(wc -l < "$secrets_found" 2>/dev/null || echo 0)
                echo "[+] Found $secrets_count potential secrets in JavaScript files"
            else
                echo "[-] No secrets found"
                touch "$secrets_found"
            fi
        fi
        
        # Clean up downloaded files
        echo "[+] Cleaning up downloaded files..."
        rm -rf "$js_downloads_dir"
        
    else
        echo "[-] No JavaScript files to download"
        touch "${TARGET_DIR}/extracted_urls.txt" "${TARGET_DIR}/js_secrets.txt"
    fi
    
    log_info "JavaScript analysis completed"
    notify_module_done "js_analysis" "${TARGET_DIR}/extracted_urls.txt"
}

#######################################
# Simplified reconnaissance workflow
#######################################

run_discovery() {
    log_info "Starting discovery phase - subdomain enumeration"
    
    echo "[+] ==> DISCOVERY PHASE: Subdomain Enumeration"
    
    # Step 1: Subdomain discovery with immediate alive filtering
    echo "[+] Phase 1: Recursive subdomain discovery and alive filtering..."
    timeout 600 subfinder -d "$TARGET" -recursive 2>/dev/null | httpx -silent -o "${TARGET_DIR}/alive_subs.txt" 2>/dev/null || echo "[-] Subfinder/httpx failed"
    
    if [[ -f "${TARGET_DIR}/alive_subs.txt" && -s "${TARGET_DIR}/alive_subs.txt" ]]; then
        local subs_count=$(wc -l < "${TARGET_DIR}/alive_subs.txt")
        echo "[+] Found $subs_count alive subdomains"
    else
        echo "[-] No alive subdomains found"
        touch "${TARGET_DIR}/alive_subs.txt"
    fi
    
    log_info "Discovery phase completed"
    notify_module_done "discovery" "${TARGET_DIR}/alive_subs.txt"
}

run_analysis() {
    log_info "Starting analysis phase - reporting and summary"
    
    echo "[+] ==> ANALYSIS PHASE: Reporting and Summary"
    
    # Clean up unnecessary files
    echo "[+] Phase 1: Cleaning up unnecessary files..."
    rm -f "${TARGET_DIR}/katana_js_files.txt" 2>/dev/null || true
    rm -f "${TARGET_DIR}/gau_js_files.txt" 2>/dev/null || true
    rm -f "${TARGET_DIR}/all_js_files.txt" 2>/dev/null || true
    rm -f "${TARGET_DIR}/vulns.txt" 2>/dev/null || true

    
    # Step 2: Generate comprehensive summary
    echo "[+] Phase 2: Generating comprehensive summary..."
    local summary_file="${TARGET_DIR}/resumen.txt"
    
    cat << EOF > "$summary_file"
# 🎯 Bug Bounty Reconnaissance Report for $TARGET
Generated on: $(date)

## 📊 Discovery Statistics
EOF
    
    # Calculate statistics
    local alive_subs_count=$(wc -l < "${TARGET_DIR}/alive_subs.txt" 2>/dev/null || echo 0)
    local alive_js_count=$(wc -l < "${TARGET_DIR}/alive_js_files.txt" 2>/dev/null || echo 0)
    local extracted_urls_count=$(wc -l < "${TARGET_DIR}/extracted_urls.txt" 2>/dev/null || echo 0)
    local secrets_count=$(wc -l < "${TARGET_DIR}/js_secrets.txt" 2>/dev/null || echo 0)
    
    cat << EOF >> "$summary_file"
- 🌐 Alive subdomains: $alive_subs_count
- 📜 Alive JavaScript files: $alive_js_count
- 🔗 URLs extracted from JS files: $extracted_urls_count
- 🔑 Secrets found in JS files: $secrets_count

## 📁 Generated Files
- alive_subs.txt - Live subdomains
- alive_js_files.txt - Verified alive JavaScript files
- extracted_urls.txt - URLs extracted from JS files
- js_secrets.txt - Secrets found in JavaScript files

## 🎯 Next Steps
1. Manual review of JavaScript files for sensitive data
2. Test extracted URLs for authentication bypasses
3. Analyze secrets found for potential exposures

---
Generated by bbrecon framework
EOF
    
    local total_findings=$((alive_subs_count + alive_js_count + extracted_urls_count + secrets_count))
    echo "[+] Analysis complete: $total_findings total findings across all categories"
    
    # Generate beautiful HTML report
    echo "[+] Generating comprehensive HTML report..."
    generate_html_report "$TARGET" "$TARGET_DIR"
    
    log_info "Analysis phase completed" 
    notify_module_done "analysis" "$summary_file"
}

#######################################
# Main flow
#######################################

main() {
    local target_arg=""
    local no_telegram=false
    
    # If no arguments provided, show help
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                target_arg="$2"
                shift 2
                ;;
            --no-telegram)
                no_telegram=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Error: Unknown argument: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done
    
    # Configure initial logging
    ensure_dir "${BASE_DIR}/logs"
    
    # Load configuration
    load_config
    
    # Disable Telegram if specified
    if [[ "$no_telegram" == true ]]; then
        TELEGRAM_ENABLED=false
    fi
    
    # Get target
    if [[ -n "$target_arg" ]]; then
        TARGET="$target_arg"
    else
        read -r -p "Enter the target (domain): " TARGET
    fi
    
    # Validate target
    if ! validate_target "$TARGET"; then
        exit 1
    fi
    
    # Configure specific log file
    LOG_FILE="${BASE_DIR}/logs/bbrecon-${TARGET}-$(timestamp).log"
    
    # Display banner
    show_banner
    
    log_info "=== Starting bbrecon for target: $TARGET ==="
    
    # Handle existing target directory
    handle_existing_target_dir
    
    # Create target directory
    ensure_dir "$TARGET_DIR"
    
    # Start notification
    send_message "🚀 bbrecon started for \`${TARGET}\`"
    
    # Execute simplified workflow
    run_discovery
    run_js_crawling
    run_js_analysis
    run_analysis
    
    # Final notification
    send_message "✅ Reconnaissance completed for \`${TARGET}\`"
    
    # Send summary and HTML report if they exist
    local resumen_file="${TARGET_DIR}/resumen.txt"
    local html_report="${TARGET_DIR}/bbrecon_report.html"
    
    if [[ -f "$resumen_file" ]]; then
        send_document "$resumen_file"
    fi
    
    if [[ -f "$html_report" ]]; then
        send_document "$html_report"
        echo "📊 Beautiful HTML report available at: $html_report"
    fi
    
    log_info "=== bbrecon completed for target: $TARGET ==="
    echo "Reconnaissance completed. Files generated in: $TARGET_DIR"
    echo "📊 Open $html_report in your browser for a detailed visual report!"
}

# Execute main function with all arguments
main "$@"