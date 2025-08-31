#!/usr/bin/env bash

# telegram.sh - Telegram notification utilities
# Strict bash configuration
set -Eeuo pipefail
IFS=$'\n\t'

#######################################
# Send text message via Telegram
# Arguments:
#   $1 - Message to send
#######################################
send_message() {
    local message="$1"
    
    # Check if Telegram is enabled
    if [[ "${TELEGRAM_ENABLED:-true}" != "true" ]]; then
        return 0
    fi
    
    # Check required variables
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${CHAT_ID:-}" ]]; then
        echo "[WARN] TELEGRAM_BOT_TOKEN or CHAT_ID variables not configured - skipping notification"
        return 0
    fi
    
    # Telegram API URL
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    
    # Send message using curl
    local response
    if response=$(curl -s -X POST "$api_url" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" \
        --connect-timeout 10 \
        --max-time 30 2>&1); then
        
        # Check if response indicates success
        if echo "$response" | grep -q '"ok":true'; then
            echo "[INFO] Telegram message sent successfully"
        else
            echo "[WARN] Error in Telegram response: $response"
        fi
    else
        echo "[WARN] Error sending Telegram message: $response"
    fi
}

#######################################
# Send document via Telegram
# Arguments:
#   $1 - Path to file to send
#######################################
send_document() {
    local file_path="$1"
    
    # Check if Telegram is enabled
    if [[ "${TELEGRAM_ENABLED:-true}" != "true" ]]; then
        return 0
    fi
    
    # Check required variables
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${CHAT_ID:-}" ]]; then
        echo "[WARN] TELEGRAM_BOT_TOKEN or CHAT_ID variables not configured - skipping document send"
        return 0
    fi
    
    # Check that file exists
    if [[ ! -f "$file_path" ]]; then
        echo "[WARN] File not found: $file_path - skipping send"
        return 0
    fi
    
    # Check that file is not empty
    if [[ ! -s "$file_path" ]]; then
        echo "[WARN] Empty file: $file_path - skipping send"
        return 0
    fi
    
    # Telegram API URL
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
    
    # Send document using curl
    local response
    if response=$(curl -s -X POST "$api_url" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@${file_path}" \
        --connect-timeout 10 \
        --max-time 60 2>&1); then
        
        # Check if response indicates success
        if echo "$response" | grep -q '"ok":true'; then
            echo "[INFO] Telegram document sent successfully: $(basename "$file_path")"
        else
            echo "[WARN] Error in Telegram response: $response"
        fi
    else
        echo "[WARN] Error sending Telegram document: $response"
    fi
}

#######################################
# Check Telegram configuration
#######################################
check_telegram_config() {
    if [[ "${TELEGRAM_ENABLED:-true}" != "true" ]]; then
        echo "[INFO] Telegram notifications disabled"
        return 0
    fi
    
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        echo "[WARN] TELEGRAM_BOT_TOKEN not configured"
        return 1
    fi
    
    if [[ -z "${CHAT_ID:-}" ]]; then
        echo "[WARN] CHAT_ID not configured"
        return 1
    fi
    
    echo "[INFO] Telegram configuration validated"
    return 0
}

#######################################
# Send test message
#######################################
test_telegram() {
    check_telegram_config || return 1
    
    local test_message="🧪 Test message from bbrecon - $(date)"
    send_message "$test_message"
}

# If script is executed directly (not as source)
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
    echo "Telegram utilities script for bbrecon"
    echo "Usage: source telegram.sh"
    echo ""
    echo "Available functions:"
    echo "  send_message \"message\"     - Send text message"
    echo "  send_document \"file\"       - Send file"
    echo "  check_telegram_config      - Check configuration"
    echo "  test_telegram              - Send test message"
fi