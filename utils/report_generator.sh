#!/usr/bin/env bash

# report_generator.sh - HTML Report Generator for bbrecon
# Generates beautiful, responsive HTML reports with findings

set -Eeuo pipefail

#######################################
# Generate comprehensive HTML report
# Arguments:
#   $1 - Target domain
#   $2 - Target directory
#######################################
generate_html_report() {
    local target="$1"
    local target_dir="$2"
    local report_file="${target_dir}/bbrecon_report.html"
    
    echo "[+] Generating HTML report..."
    
    # Calculate statistics
    local alive_subs_count=$(wc -l < "${target_dir}/alive_subs.txt" 2>/dev/null || echo 0)
    local js_files_count=$(wc -l < "${target_dir}/alive_jsfile.txt" 2>/dev/null || echo 0)
    local vulns_count=$(wc -l < "${target_dir}/vulns.txt" 2>/dev/null || echo 0)
    local hidden_endpoints_count=$(wc -l < "${target_dir}/hidden_endpoints.txt" 2>/dev/null || echo 0)
    
    # Analyze for sensitive findings
    analyze_sensitive_data "$target_dir" || {
        echo "[WARN] Failed to analyze sensitive data, continuing..."
    }
    
    # Generate HTML
    cat << 'EOF' > "$report_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>bbrecon Report - TARGET_PLACEHOLDER</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
            position: relative;
        }
        
        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="50" cy="50" r="1" fill="white" opacity="0.1"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            position: relative;
            z-index: 1;
        }
        
        .header .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
            position: relative;
            z-index: 1;
        }
        
        .meta-info {
            background: #f8f9fa;
            padding: 20px 40px;
            border-bottom: 1px solid #e9ecef;
        }
        
        .meta-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        
        .meta-item {
            text-align: center;
        }
        
        .meta-label {
            font-size: 0.9rem;
            color: #6c757d;
            margin-bottom: 5px;
        }
        
        .meta-value {
            font-size: 1.1rem;
            font-weight: 600;
            color: #495057;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 30px;
            padding: 40px;
        }
        
        .stat-card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            border: 1px solid #e9ecef;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
        }
        
        .stat-icon {
            font-size: 3rem;
            margin-bottom: 15px;
            display: block;
        }
        
        .stat-number {
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .stat-label {
            font-size: 1.1rem;
            color: #6c757d;
            font-weight: 500;
        }
        
        .findings-section {
            padding: 40px;
            background: #f8f9fa;
        }
        
        .section-title {
            font-size: 2rem;
            margin-bottom: 30px;
            color: #495057;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        
        .finding-card {
            background: white;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
            overflow: hidden;
        }
        
        .finding-header {
            padding: 20px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .finding-content {
            padding: 0 20px 20px;
            max-height: 300px;
            overflow-y: auto;
        }
        
        .finding-list {
            list-style: none;
        }
        
        .finding-item {
            padding: 8px 0;
            border-bottom: 1px solid #e9ecef;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
            word-break: break-all;
        }
        
        .finding-item:last-child {
            border-bottom: none;
        }
        
        .severity-critical { background: #dc3545; color: white; }
        .severity-high { background: #fd7e14; color: white; }
        .severity-medium { background: #ffc107; color: black; }
        .severity-low { background: #28a745; color: white; }
        .severity-info { background: #17a2b8; color: white; }
        
        .badge {
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 500;
        }
        
        .expandable {
            cursor: pointer;
        }
        
        .expandable:hover {
            background: #f8f9fa;
        }
        
        .hidden {
            display: none;
        }
        
        .footer {
            background: #343a40;
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .footer a {
            color: #67eea;
            text-decoration: none;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            .stats-grid {
                grid-template-columns: 1fr;
                padding: 20px;
            }
            .findings-section {
                padding: 20px;
            }
        }
        
        .api-key-item {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 12px;
            margin: 8px 0;
        }
        
        .endpoint-item {
            background: #d1ecf1;
            border: 1px solid #bee5eb;
            border-radius: 8px;
            padding: 10px;
            margin: 6px 0;
            font-family: 'Courier New', monospace;
        }
        
        .vuln-item {
            background: #f8d7da;
            border: 1px solid #f5c6cb;
            border-radius: 8px;
            padding: 12px;
            margin: 8px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>🎯 bbrecon Report</h1>
            <div class="subtitle">Bug Bounty Reconnaissance Results for <strong>TARGET_PLACEHOLDER</strong></div>
        </div>
        
        <!-- Meta Information -->
        <div class="meta-info">
            <div class="meta-grid">
                <div class="meta-item">
                    <div class="meta-label">Generated On</div>
                    <div class="meta-value">DATE_PLACEHOLDER</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">Scan Duration</div>
                    <div class="meta-value">DURATION_PLACEHOLDER</div>
                </div>
                <div class="meta-item">
                    <div class="meta-label">bbrecon Version</div>
                    <div class="meta-value">v2.0</div>
                </div>
            </div>
        </div>
        
        <!-- Statistics -->
        <div class="stats-grid">
            <div class="stat-card">
                <span class="stat-icon">🌐</span>
                <div class="stat-number" style="color: #28a745;">ALIVE_SUBS_COUNT</div>
                <div class="stat-label">Live Subdomains</div>
            </div>

            <div class="stat-card">
                <span class="stat-icon">📜</span>
                <div class="stat-number" style="color: #6f42c1;">JS_FILES_COUNT</div>
                <div class="stat-label">JavaScript Files</div>
            </div>
            <div class="stat-card">
                <span class="stat-icon">🔗</span>
                <div class="stat-number" style="color: #fd7e14;">ENDPOINTS_COUNT</div>
                <div class="stat-label">Endpoints Found</div>
            </div>
            <div class="stat-card">
                <span class="stat-icon">🚨</span>
                <div class="stat-number" style="color: #dc3545;">VULNS_COUNT</div>
                <div class="stat-label">Vulnerabilities</div>
            </div>
            <div class="stat-card">
                <span class="stat-icon">🔑</span>
                <div class="stat-number" style="color: #e83e8c;">API_KEYS_COUNT</div>
                <div class="stat-label">Sensitive Data</div>
            </div>
        </div>
        
        <!-- Findings Section -->
        <div class="findings-section">
            <h2 class="section-title">🔍 Detailed Findings</h2>
            
            <!-- API Keys and Sensitive Data -->
            <div class="finding-card">
                <div class="finding-header expandable" onclick="toggleSection('api-keys')">
                    <span>🔑</span>
                    <span>API Keys & Sensitive Data</span>
                    <span class="badge severity-critical">API_KEYS_COUNT found</span>
                </div>
                <div id="api-keys" class="finding-content">
                    API_KEYS_CONTENT
                </div>
            </div>
            
            <!-- Vulnerabilities -->
            <div class="finding-card">
                <div class="finding-header expandable" onclick="toggleSection('vulnerabilities')">
                    <span>🚨</span>
                    <span>Vulnerabilities</span>
                    <span class="badge severity-high">VULNS_COUNT found</span>
                </div>
                <div id="vulnerabilities" class="finding-content">
                    VULNERABILITIES_CONTENT
                </div>
            </div>
            
            <!-- Hidden Endpoints -->
            <div class="finding-card">
                <div class="finding-header expandable" onclick="toggleSection('hidden-endpoints')">
                    <span>🔗</span>
                    <span>Hidden Endpoints (from JS analysis)</span>
                    <span class="badge severity-medium">HIDDEN_ENDPOINTS_COUNT found</span>
                </div>
                <div id="hidden-endpoints" class="finding-content">
                    HIDDEN_ENDPOINTS_CONTENT
                </div>
            </div>
            
            <!-- Live Subdomains -->
            <div class="finding-card">
                <div class="finding-header expandable" onclick="toggleSection('subdomains')">
                    <span>🌐</span>
                    <span>Live Subdomains</span>
                    <span class="badge severity-info">ALIVE_SUBS_COUNT found</span>
                </div>
                <div id="subdomains" class="finding-content">
                    SUBDOMAINS_CONTENT
                </div>
            </div>
            
            <!-- JavaScript Files -->
            <div class="finding-card">
                <div class="finding-header expandable" onclick="toggleSection('js-files')">
                    <span>📜</span>
                    <span>JavaScript Files</span>
                    <span class="badge severity-info">JS_FILES_COUNT found</span>
                </div>
                <div id="js-files" class="finding-content">
                    JS_FILES_CONTENT
                </div>
            </div>
            

        </div>
        
        <!-- Footer -->
        <div class="footer">
            <p>Generated by <strong>bbrecon</strong> - Bug Bounty Reconnaissance Framework</p>
            <p>🎯 Happy Bug Hunting! | <a href="https://github.com/l0n3f/bbrecon">GitHub Repository</a></p>
        </div>
    </div>
    
    <script>
        function toggleSection(sectionId) {
            const section = document.getElementById(sectionId);
            if (section.style.display === 'none' || section.style.display === '') {
                section.style.display = 'block';
            } else {
                section.style.display = 'none';
            }
        }
        
        // Initially hide all sections
        document.addEventListener('DOMContentLoaded', function() {
            const sections = ['api-keys', 'vulnerabilities', 'hidden-endpoints', 'subdomains', 'js-files'];
            sections.forEach(id => {
                const section = document.getElementById(id);
                if (section) {
                    section.style.display = 'none';
                }
            });
        });
    </script>
</body>
</html>
EOF

    # Replace placeholders with actual data
    replace_placeholders "$report_file" "$target" "$target_dir" \
        "$alive_subs_count" "$js_files_count" \
        "$vulns_count" "$hidden_endpoints_count" || {
        echo "[ERROR] Failed to replace placeholders in HTML report"
        return 1
    }
    
    echo "[+] HTML report generated: $report_file"
    return 0
}

#######################################
# Analyze files for sensitive data
#######################################
analyze_sensitive_data() {
    local target_dir="$1"
    local sensitive_file="${target_dir}/sensitive_findings.txt"
    
    echo "[+] Analyzing for sensitive data..."
    : > "$sensitive_file"
    
    # API Keys patterns (Updated with correct lengths and more flexible matching)
    local api_patterns=(
        "AIza[0-9A-Za-z\\-_]{35,}"   # Google API (35+ chars, actual is 39)
        "AKIA[0-9A-Z]{16}"           # AWS Access Key
        "sk_live_[0-9a-zA-Z]{24,}"   # Stripe Live Key (24+ chars)
        "sk_test_[0-9a-zA-Z]{24,}"   # Stripe Test Key (24+ chars) 
        "rk_live_[0-9a-zA-Z]{24,}"   # Stripe Restricted Key (24+ chars)
        "ghp_[0-9a-zA-Z]{36,}"       # GitHub Personal Access Token (36+ chars)
        "xox[baprs]-[0-9a-zA-Z-]+"   # Slack Token
        "[0-9]+-[0-9A-Za-z_]{32,}"   # Facebook Access Token (32+ chars)
        "ya29\\.[0-9A-Za-z\\-_]+"    # Google OAuth Access Token
    )
    
    # Search in JS files
    if [[ -f "${target_dir}/alive_jsfile.txt" ]]; then
        while IFS= read -r jsfile; do
            local content=$(curl -s --max-time 10 "$jsfile" 2>/dev/null || echo "")
            for pattern in "${api_patterns[@]}"; do
                echo "$content" | grep -oE "$pattern" 2>/dev/null | while read match; do
                    echo "API_KEY|$jsfile|$match" >> "$sensitive_file"
                done || true
            done
        done < "${target_dir}/alive_jsfile.txt"
    fi
    
    # Search for other sensitive patterns (fixed regex compatibility)
    local sensitive_patterns=(
        "password[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{3,}[\"']"
        "secret[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{3,}[\"']"
        "token[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "apikey[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "api[_-]?key[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "apiKey[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "private[_-]?key[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{20,}[\"']"
        "access[_-]?token[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "refresh[_-]?token[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "auth[_-]?token[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "authToken[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
        "refreshToken[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"']{10,}[\"']"
    )
    
    if [[ -f "${target_dir}/alive_jsfile.txt" ]]; then
        while IFS= read -r jsfile; do
            local content=$(curl -s --max-time 10 "$jsfile" 2>/dev/null || echo "")
            for pattern in "${sensitive_patterns[@]}"; do
                echo "$content" | grep -oiE "$pattern" 2>/dev/null | while read match; do
                    echo "SENSITIVE|$jsfile|$match" >> "$sensitive_file"
                done || true
            done
        done < "${target_dir}/alive_jsfile.txt"
    fi
}

#######################################
# Replace placeholders in HTML template
#######################################
replace_placeholders() {
    local report_file="$1"
    local target="$2"
    local target_dir="$3"
    local alive_subs_count="$4"
    local js_files_count="$5"
    local vulns_count="$6"
    local hidden_endpoints_count="$7"
    
    # Calculate API keys count
    local api_keys_count=0
    if [[ -f "${target_dir}/sensitive_findings.txt" ]]; then
        api_keys_count=$(wc -l < "${target_dir}/sensitive_findings.txt" 2>/dev/null || echo 0)
    fi
    
    # Replace basic placeholders
    sed -i "s/TARGET_PLACEHOLDER/$target/g" "$report_file" 2>/dev/null || true
    sed -i "s/DATE_PLACEHOLDER/$(date)/g" "$report_file" 2>/dev/null || true
    sed -i "s/DURATION_PLACEHOLDER/$(calculate_duration)/g" "$report_file" 2>/dev/null || true
    sed -i "s/ALIVE_SUBS_COUNT/$alive_subs_count/g" "$report_file" 2>/dev/null || true
    sed -i "s/PORTS_COUNT/0/g" "$report_file" 2>/dev/null || true
    sed -i "s/JS_FILES_COUNT/$js_files_count/g" "$report_file" 2>/dev/null || true
    sed -i "s/ENDPOINTS_COUNT/$hidden_endpoints_count/g" "$report_file" 2>/dev/null || true
    sed -i "s/VULNS_COUNT/$vulns_count/g" "$report_file" 2>/dev/null || true
    sed -i "s/HIDDEN_ENDPOINTS_COUNT/$hidden_endpoints_count/g" "$report_file" 2>/dev/null || true
    sed -i "s/API_KEYS_COUNT/$api_keys_count/g" "$report_file" 2>/dev/null || true
    
    # Generate content sections using temporary files (sed -i with /r doesn't work reliably)
    local temp_file=$(mktemp)
    
    # API Keys content
    generate_api_keys_content "$target_dir" > "$temp_file"
    sed -i "/API_KEYS_CONTENT/r $temp_file" "$report_file" 2>/dev/null || true
    sed -i '/API_KEYS_CONTENT/d' "$report_file" 2>/dev/null || true
    
    # Vulnerabilities content  
    generate_vulnerabilities_content "$target_dir" > "$temp_file"
    sed -i "/VULNERABILITIES_CONTENT/r $temp_file" "$report_file" 2>/dev/null || true
    sed -i '/VULNERABILITIES_CONTENT/d' "$report_file" 2>/dev/null || true
    
    # Hidden endpoints content
    generate_hidden_endpoints_content "$target_dir" > "$temp_file"
    sed -i "/HIDDEN_ENDPOINTS_CONTENT/r $temp_file" "$report_file" 2>/dev/null || true
    sed -i '/HIDDEN_ENDPOINTS_CONTENT/d' "$report_file" 2>/dev/null || true
    
    # Subdomains content
    generate_subdomains_content "$target_dir" > "$temp_file"
    sed -i "/SUBDOMAINS_CONTENT/r $temp_file" "$report_file" 2>/dev/null || true
    sed -i '/SUBDOMAINS_CONTENT/d' "$report_file" 2>/dev/null || true
    
    # JS files content
    generate_js_files_content "$target_dir" > "$temp_file"
    sed -i "/JS_FILES_CONTENT/r $temp_file" "$report_file" 2>/dev/null || true
    sed -i '/JS_FILES_CONTENT/d' "$report_file" 2>/dev/null || true
    
    # Clean up temporary file
    rm -f "$temp_file"
}

#######################################
# Generate content sections
#######################################
generate_api_keys_content() {
    local target_dir="$1"
    if [[ -f "${target_dir}/sensitive_findings.txt" && -s "${target_dir}/sensitive_findings.txt" ]]; then
        echo "<ul class='finding-list'>"
        while IFS='|' read -r type source finding; do
            echo "<li class='api-key-item'>"
            echo "<strong>Type:</strong> $type<br>"
            echo "<strong>Source:</strong> $source<br>"
            echo "<strong>Finding:</strong> <code>$finding</code>"
            echo "</li>"
        done < "${target_dir}/sensitive_findings.txt"
        echo "</ul>"
    else
        echo "<p>No API keys or sensitive data found.</p>"
    fi
}

generate_vulnerabilities_content() {
    local target_dir="$1"
    if [[ -f "${target_dir}/vulns.txt" && -s "${target_dir}/vulns.txt" ]]; then
        echo "<ul class='finding-list'>"
        head -50 "${target_dir}/vulns.txt" | while IFS= read -r vuln; do
            echo "<li class='vuln-item'>$vuln</li>"
        done
        echo "</ul>"
    else
        echo "<p>No vulnerabilities found.</p>"
    fi
}

generate_hidden_endpoints_content() {
    local target_dir="$1"
    if [[ -f "${target_dir}/hidden_endpoints.txt" && -s "${target_dir}/hidden_endpoints.txt" ]]; then
        echo "<ul class='finding-list'>"
        head -100 "${target_dir}/hidden_endpoints.txt" | while IFS= read -r endpoint; do
            echo "<li class='endpoint-item'>$endpoint</li>"
        done
        echo "</ul>"
    else
        echo "<p>No hidden endpoints found.</p>"
    fi
}

generate_subdomains_content() {
    local target_dir="$1"
    if [[ -f "${target_dir}/alive_subs.txt" && -s "${target_dir}/alive_subs.txt" ]]; then
        echo "<ul class='finding-list'>"
        while IFS= read -r subdomain; do
            echo "<li class='finding-item'>$subdomain</li>"
        done < "${target_dir}/alive_subs.txt"
        echo "</ul>"
    else
        echo "<p>No live subdomains found.</p>"
    fi
}

generate_js_files_content() {
    local target_dir="$1"
    if [[ -f "${target_dir}/alive_jsfile.txt" && -s "${target_dir}/alive_jsfile.txt" ]]; then
        echo "<ul class='finding-list'>"
        while IFS= read -r jsfile; do
            echo "<li class='finding-item'><a href='$jsfile' target='_blank'>$jsfile</a></li>"
        done < "${target_dir}/alive_jsfile.txt"
        echo "</ul>"
    else
        echo "<p>No JavaScript files found.</p>"
    fi
}



calculate_duration() {
    # Simple duration calculation based on log timestamps if available
    local duration="~45 minutes"  # Default placeholder
    
    # Try to calculate from log file if available
    if [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]]; then
        local start_time=$(head -1 "$LOG_FILE" 2>/dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' | head -1)
        local end_time=$(tail -1 "$LOG_FILE" 2>/dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' | tail -1)
        
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            local start_seconds=$(date -d "$start_time" +%s 2>/dev/null)
            local end_seconds=$(date -d "$end_time" +%s 2>/dev/null)
            
            if [[ -n "$start_seconds" && -n "$end_seconds" ]]; then
                local diff=$((end_seconds - start_seconds))
                local minutes=$((diff / 60))
                duration="${minutes} minutes"
            fi
        fi
    fi
    
    echo "$duration"
}

# If script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <target> <target_directory>"
        exit 1
    fi
    generate_html_report "$1" "$2"
fi