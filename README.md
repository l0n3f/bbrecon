# 🎯 bbrecon - Bug Bounty Reconnaissance Framework

An automated reconnaissance framework designed for bug bounty hunting that combines subdomain discovery, JavaScript file analysis, and vulnerability scanning with real-time Telegram notifications.

## 🚀 Features

- **Comprehensive Subdomain Discovery**: Recursive enumeration with alive filtering
- **JavaScript File Analysis**: Deep crawling and endpoint extraction from JS files
- **Port Scanning**: Efficient scanning on live hosts only
- **Vulnerability Scanning**: Automated nuclei scans for tokens and vulnerabilities
- **Real-time Notifications**: Telegram integration for progress updates
- **Detailed Reporting**: Comprehensive summary with statistics and next steps
- **Error Handling**: Robust error management with automatic notifications

## 📁 Project Structure

```
bbrecon/
├── bbrecon.sh              # Main reconnaissance script
├── env.example             # Configuration template
├── README.md               # This file
├── logs/                   # Execution logs directory
└── utils/
    └── telegram.sh         # Telegram notification utilities
```

## 🛠️ Installation

### Prerequisites

Install the required tools:

```bash
# Go-based tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Additional tools
go install github.com/lc/gau@latest
go install github.com/tomnomnom/waybackurls@latest

# System tools
sudo apt install nmap curl jq
```

### Setup

1. **Clone or download the project**:
```bash
git clone <repository-url>
cd bbrecon
```

2. **Make scripts executable**:
```bash
chmod +x bbrecon.sh utils/telegram.sh
```

3. **Configure environment**:
```bash
cp env.example .env
nano .env  # Edit with your configuration
```

## ⚙️ Configuration

### Telegram Bot Setup

1. **Create a Telegram bot**:
   - Message @BotFather on Telegram
   - Use `/newbot` to create a new bot
   - Copy the provided token

2. **Get your Chat ID**:
   - Message @userinfobot on Telegram to get your chat ID
   - Or add the bot to a group and get the group ID

3. **Configure .env file**:
```bash
TELEGRAM_BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"
TELEGRAM_ENABLED=true
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | Required |
| `CHAT_ID` | Your Telegram chat ID | Required |
| `TELEGRAM_ENABLED` | Enable/disable notifications | `true` |
| `SEND_ARCHIVE` | Send compressed results | `false` |
| `LOG_LEVEL` | Logging level | `INFO` |

## 🎯 Usage

### Basic Usage

```bash
# Interactive mode (prompts for target)
./bbrecon.sh

# Specify target directly
./bbrecon.sh -t example.com

# Disable Telegram notifications
./bbrecon.sh --no-telegram -t example.com

# Show help
./bbrecon.sh --help
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-t, --target TARGET` | Specify target domain directly |
| `--no-telegram` | Disable Telegram notifications |
| `-h, --help` | Show help message |

## 🔄 Workflow

### Phase 1: Discovery
1. **Subdomain Discovery**: Recursive enumeration using subfinder
2. **Alive Filtering**: HTTP probing to identify responsive subdomains
3. **Port Scanning**: Nmap scan on alive hosts (top 1000 ports)
4. **JavaScript Discovery**: Web crawling with katana to find JS files
5. **Endpoint Extraction**: Regex analysis of JS files for hidden endpoints

### Phase 2: Analysis
1. **Vulnerability Scanning**: Nuclei scans for tokens and vulnerabilities
2. **Report Generation**: Comprehensive summary with statistics
3. **File Organization**: Structured output for manual review

## 📊 Output Files

After execution, you'll find these files in `/home/l0n3/bugbounty/<target>/`:

| File | Description |
|------|-------------|
| `alive_subs.txt` | Live subdomains |
| `ports.txt` | Open ports (IP:Port format) |
| `alive_jsfile.txt` | Active JavaScript files |
| `hidden_endpoints.txt` | Endpoints extracted from JS files |
| `vulns.txt` | Vulnerability findings |
| `nuclei_tokens.json` | Token/credential exposures |
| `resumen.txt` | Comprehensive report |

## 📱 Telegram Notifications

You'll receive real-time notifications for:

- 🚀 **Start**: When reconnaissance begins
- ✅ **Discovery Complete**: With subdomain count
- ✅ **Analysis Complete**: With summary statistics
- ✅ **Final Report**: With attached summary document
- ❌ **Errors**: If any critical failures occur

Example notification:
```
✅ discovery completed for example.com — 45 lines in alive_subs.txt
```

## 📝 Logging

Each execution generates a detailed log file:
```
logs/bbrecon-<target>-<timestamp>.log
```

Log entries include:
- Timestamps for all operations
- Success/failure status
- Tool outputs and errors
- Performance metrics

## 🎨 Customization

### Adding Custom Tools

You can easily extend the framework by modifying the discovery and analysis phases in `bbrecon.sh`:

```bash
# In run_discovery() function
echo "[+] Running custom subdomain tool..."
your_custom_tool -d "$TARGET" >> "${TARGET_DIR}/custom_results.txt"

# In run_analysis() function  
echo "[+] Running custom vulnerability scanner..."
your_vuln_scanner -l "${TARGET_DIR}/alive_subs.txt" >> "${TARGET_DIR}/vulns.txt"
```

### Directory Management

The script handles existing target directories with three options:
1. **Overwrite**: Moves existing directory to timestamped backup
2. **Append**: Keeps existing files and adds new results
3. **Cancel**: Exits without changes

## 🔧 Advanced Features

### Error Handling
- Automatic error detection and Telegram notifications
- Graceful degradation when tools fail
- Comprehensive logging for debugging

### Performance Optimization
- Only scans alive hosts for ports
- Efficient pipeline processing
- Rate limiting for external APIs

### Security
- Secure .env file handling (add to .gitignore)
- No hardcoded credentials
- Configurable timeouts and rate limits

## 🐛 Troubleshooting

### Common Issues

1. **Tools not found**:
```bash
# Verify tools are in PATH
which subfinder httpx katana nuclei nmap
```

2. **Telegram not working**:
```bash
# Test Telegram configuration
source utils/telegram.sh && test_telegram
```

3. **Permission denied**:
```bash
# Make scripts executable
chmod +x bbrecon.sh utils/telegram.sh
```

4. **Empty results**:
   - Check target domain is valid and accessible
   - Verify tools have proper configuration
   - Review log files for detailed error messages

### Debug Mode

Enable verbose logging by modifying the script:
```bash
# Add at the top of bbrecon.sh
set -x  # Enable debug mode
```

## 📋 Best Practices

1. **Always use .env**: Never hardcode sensitive tokens
2. **Regular updates**: Keep tools updated for best results
3. **Rate limiting**: Respect target rate limits to avoid blocking
4. **Manual review**: Always manually verify automated findings
5. **Responsible disclosure**: Follow responsible disclosure practices

## 🔐 Security Considerations

- Store .env files securely (never commit to version control)
- Use dedicated Telegram bots for different projects
- Regularly rotate API tokens
- Monitor tool outputs for sensitive data exposure

## 📚 Example Workflow

```bash
# 1. Setup
cp env.example .env
nano .env  # Configure Telegram

# 2. Run reconnaissance
./bbrecon.sh -t example.com

# 3. Review results
cd /home/l0n3/bugbounty/example.com
cat resumen.txt

# 4. Manual analysis
less alive_jsfile.txt
grep -i "api" hidden_endpoints.txt
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📜 License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## ⚠️ Disclaimer

This tool is for educational and authorized security testing purposes only. Users are responsible for complying with applicable laws and obtaining proper authorization before testing any systems they do not own.

## 🙋‍♂️ Support

For issues, questions, or feature requests:
1. Check the troubleshooting section
2. Review existing issues
3. Create a new issue with detailed information

---

**Happy Bug Hunting! 🐛💰**