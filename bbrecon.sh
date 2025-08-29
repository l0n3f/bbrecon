#!/usr/bin/env bash

# bbrecon.sh - Bug Bounty Reconnaissance Framework
# Strict bash configuration
set -Eeuo pipefail
IFS=$'\n\t'

# Base configuration
readonly BASE_DIR="/home/l0n3/bugbounty"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables
TARGET=""
TARGET_DIR=""
LOG_FILE=""
TELEGRAM_ENABLED=true

# Load utilities
source "${SCRIPT_DIR}/utils/telegram.sh"
source "${SCRIPT_DIR}/utils/report_generator.sh"

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
    local env_file="${BASE_DIR}/.env"
    
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
# Simplified reconnaissance workflow
#######################################

run_discovery() {
    log_info "Starting discovery phase - comprehensive recon workflow"
    
    echo "[+] ==> DISCOVERY PHASE: Subdomains, JS Files, and Content Analysis"
    
    # Step 1: Subdomain discovery with immediate alive filtering
    echo "[+] Phase 1: Recursive subdomain discovery and alive filtering..."
    subfinder -d "$TARGET" -recursive | httpx -o "${TARGET_DIR}/alive_subs.txt" || echo "[-] Subfinder/httpx failed"
    
    if [[ -f "${TARGET_DIR}/alive_subs.txt" && -s "${TARGET_DIR}/alive_subs.txt" ]]; then
        local subs_count=$(wc -l < "${TARGET_DIR}/alive_subs.txt")
        echo "[+] Found $subs_count alive subdomains"
        
        # Step 2: Port scanning on alive hosts only
        echo "[+] Phase 2: Port scanning on alive hosts..."
        nmap -iL "${TARGET_DIR}/alive_subs.txt" --top-ports 1000 -T4 --open -oG "${TARGET_DIR}/nmap.gnmap" || echo "[-] Nmap failed"
        grep -oP '\d+\.\d+\.\d+\.\d+:\d+' "${TARGET_DIR}/nmap.gnmap" > "${TARGET_DIR}/ports.txt" 2>/dev/null || touch "${TARGET_DIR}/ports.txt"
        
        # Step 3: JS file discovery with katana
        echo "[+] Phase 3: Crawling for JS files and endpoints..."
        cat "${TARGET_DIR}/alive_subs.txt" | katana -depth 3 -rl 2 | grep -E "\.(js|jsx)(\?|$)" | grep -v -E "\.(json|css|png|jpg|gif|svg|woff|ttf)(\?|$)" | httpx -mc 200 > "${TARGET_DIR}/alive_jsfile.txt" || echo "[-] Katana/JS discovery failed"
        
        if [[ -f "${TARGET_DIR}/alive_jsfile.txt" && -s "${TARGET_DIR}/alive_jsfile.txt" ]]; then
            local js_count=$(wc -l < "${TARGET_DIR}/alive_jsfile.txt")
            echo "[+] Found $js_count JavaScript files"
            
            # Step 4: Extract endpoints from JS files
            echo "[+] Phase 4: Extracting hidden endpoints from JS files..."
            : > "${TARGET_DIR}/endpoints.txt"
            while IFS= read -r jsfile; do
                echo "[+] Analyzing: $jsfile"
                
                # Skip non-JS files that might have slipped through
                if [[ "$jsfile" =~ \.(json|xml|css|html)(\?|$) ]]; then
                    echo "[-] Skipping non-JS file: $jsfile"
                    continue
                fi
                
                # Improved endpoint extraction with better regex and error handling
                curl -s --max-time 30 "$jsfile" 2>/dev/null \
                | grep -oE '["'"'"'][/][a-zA-Z0-9_/?=&%.\-:]*["'"'"']' 2>/dev/null \
                | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' \
                | grep -E '^/[a-zA-Z0-9_/?=&%.\-:]+$' \
                | sort -u \
                | awk -v file="$jsfile" '{print $0 " --> " file}' >> "${TARGET_DIR}/hidden_endpoints.txt" 2>/dev/null || echo "[-] Failed to analyze: $jsfile"
            done < "${TARGET_DIR}/alive_jsfile.txt"
            
            local endpoints_count=$(wc -l < "${TARGET_DIR}/hidden_endpoints.txt" 2>/dev/null || echo 0)
            echo "[+] Extracted $endpoints_count hidden endpoints"
        else
            echo "[-] No JS files found"
            touch "${TARGET_DIR}/endpoints.txt"
        fi
    else
        echo "[-] No alive subdomains found, creating empty files"
        touch "${TARGET_DIR}/ports.txt" "${TARGET_DIR}/alive_jsfile.txt" "${TARGET_DIR}/endpoints.txt" "${TARGET_DIR}/hidden_endpoints.txt"
    fi
    
    # Consolidate all endpoints into final file
    echo "[+] Consolidating endpoints..."
    : > "${TARGET_DIR}/endpoints.txt"
    if [[ -f "${TARGET_DIR}/hidden_endpoints.txt" ]]; then
        cat "${TARGET_DIR}/hidden_endpoints.txt" >> "${TARGET_DIR}/endpoints.txt" 2>/dev/null
    fi
    
    
    log_info "Discovery phase completed"
    notify_module_done "discovery" "${TARGET_DIR}/alive_subs.txt"
}

run_analysis() {
    log_info "Starting analysis phase - vulnerability scanning and reporting"
    
    echo "[+] ==> ANALYSIS PHASE: Vulnerability Scanning and Summary"
    
    # Step 1: Vulnerability scanning on JS files and alive hosts
    echo "[+] Phase 1: Nuclei scanning for tokens and vulnerabilities..."
    : > "${TARGET_DIR}/vulns.txt"
    
    # Scan JS files for tokens/exposure
    if [[ -f "${TARGET_DIR}/alive_jsfile.txt" && -s "${TARGET_DIR}/alive_jsfile.txt" ]]; then
        nuclei -l "${TARGET_DIR}/alive_jsfile.txt" -tags token,exposure -o "${TARGET_DIR}/nuclei_tokens.json" || echo "[-] Nuclei token scan failed"
        cat "${TARGET_DIR}/nuclei_tokens.json" >> "${TARGET_DIR}/vulns.txt" 2>/dev/null
    fi
    
    # Scan alive subdomains for general vulnerabilities
    if [[ -f "${TARGET_DIR}/alive_subs.txt" && -s "${TARGET_DIR}/alive_subs.txt" ]]; then
        nuclei -l "${TARGET_DIR}/alive_subs.txt" -severity medium,high,critical >> "${TARGET_DIR}/vulns.txt" || echo "[-] Nuclei general scan failed"
    fi
    
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
    local ports_count=$(wc -l < "${TARGET_DIR}/ports.txt" 2>/dev/null || echo 0)
    local js_files_count=$(wc -l < "${TARGET_DIR}/alive_jsfile.txt" 2>/dev/null || echo 0)
    local endpoints_count=$(wc -l < "${TARGET_DIR}/endpoints.txt" 2>/dev/null || echo 0)
    local vulns_count=$(wc -l < "${TARGET_DIR}/vulns.txt" 2>/dev/null || echo 0)
    
    cat << EOF >> "$summary_file"
- 🌐 Alive subdomains: $alive_subs_count
- 🔍 Open ports discovered: $ports_count  
- 📜 JavaScript files found: $js_files_count
- 🔗 Hidden endpoints extracted: $endpoints_count
- 🚨 Vulnerabilities identified: $vulns_count

## 📁 Generated Files
- alive_subs.txt - Live subdomains
- ports.txt - Open ports (IP:Port format)
- alive_jsfile.txt - Active JavaScript files
- endpoints.txt - Hidden endpoints with source files
- vulns.txt - Vulnerability findings
- nuclei_tokens.json - Token/credential exposures

## 🎯 Next Steps
1. Manual review of JavaScript files for sensitive data
2. Test extracted endpoints for authentication bypasses
3. Analyze nuclei findings for exploitable vulnerabilities
4. Port scan results review for unusual services

---
Generated by bbrecon framework
EOF
    
    local total_findings=$((alive_subs_count + js_files_count + endpoints_count + vulns_count))
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
                echo "Usage: $0 [-t|--target TARGET] [--no-telegram]"
                echo "  -t, --target TARGET    Specify target directly"
                echo "  --no-telegram         Disable Telegram notifications"
                echo "  -h, --help            Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
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
    
    log_info "=== Starting bbrecon for target: $TARGET ==="
    
    # Handle existing target directory
    handle_existing_target_dir
    
    # Create target directory
    ensure_dir "$TARGET_DIR"
    
    # Start notification
    send_message "🚀 bbrecon started for \`${TARGET}\`"
    
    # Execute simplified workflow
    run_discovery
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