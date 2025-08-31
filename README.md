# bbrecon - Bug Bounty Reconnaissance Framework

```
██████╗ ██████╗ ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
██████╔╝██████╔╝██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
██╔══██╗██╔══██╗██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
██████╔╝██████╔╝██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
================================================================
     Bug Bounty Reconnaissance Framework | Created by d0x
    Stealth Mode | Rate Limited | Secure | JS Secret Hunter
================================================================
```

An advanced stealth reconnaissance framework designed for bug bounty hunting with focus on JavaScript analysis, secret detection, and rate-limited operations to avoid detection.

## 🚀 Features

- **🔍 Stealth Subdomain Discovery**: Rate-limited enumeration with alive filtering
- **📜 JavaScript File Analysis**: Deep crawling and endpoint extraction from JS files
- **🔑 Secret Detection**: Firebase, AWS, GitHub, Stripe API keys and tokens
- **🌙 Dark Mode HTML Reports**: Beautiful responsive reports with findings
- **📱 Real-time Telegram Notifications**: Progress updates and result delivery
- **⚡ Rate Limiting**: Conservative approach to avoid WAF detection
- **🎯 No Vulnerability Scanning**: Focus on reconnaissance, not aggressive testing

## 📁 Project Structure

```
bbrecon/
├── bbrecon.sh              # Main reconnaissance script
├── env.example             # Configuration template
├── README.md               # This file
└── utils/
    ├── telegram.sh         # Telegram notification utilities
    └── report_generator.sh # HTML report generation
```

## 🛠️ Installation

### Prerequisites

Install the required tools:

```bash
# Go-based tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest

# Additional tools
go install github.com/lc/gau@latest

# System tools
sudo apt install curl wget jq
```

### Setup

1. **Clone the repository**:
```bash
git clone <repository-url>
cd bbrecon
```

2. **Make scripts executable**:
```bash
chmod +x bbrecon.sh utils/telegram.sh utils/report_generator.sh
```

3. **Configure environment**:
```bash
cp env.example .env
nano .env  # Edit with your configuration
```

4. **Global installation** (optional):
```bash
sudo ln -sf $(pwd)/bbrecon.sh /usr/local/bin/bbrecon
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
TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
CHAT_ID="123456789"
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
# Show help and options
bbrecon

# Specify target directly
bbrecon -t example.com

# Disable Telegram notifications
bbrecon --no-telegram -t example.com

# Show help
bbrecon -h
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-t, --target TARGET` | Specify target domain directly |
| `--no-telegram` | Disable Telegram notifications |
| `-h, --help` | Show help message |

## 🔄 Workflow

### Phase 1: Discovery
1. **Subdomain Discovery**: Recursive enumeration using subfinder (rate limited)
2. **Alive Filtering**: HTTP probing to identify responsive subdomains

### Phase 2: JavaScript Crawling
1. **Katana Crawling**: Web crawling with 2s delays and 2 concurrent threads
2. **GAU Historical Data**: Archive.org and other sources (2 threads)
3. **Alive Verification**: httpx verification of all discovered JS files

### Phase 3: JavaScript Analysis
1. **File Download**: curl with 3-second delays between downloads
2. **URL Extraction**: Regex analysis for hidden endpoints and APIs
3. **Secret Detection**: Precise patterns for API keys and tokens

### Phase 4: Reporting
1. **HTML Report Generation**: Dark mode responsive report
2. **Summary Creation**: Text-based findings summary
3. **Telegram Delivery**: Automatic report and file delivery

## 📊 Output Files

Results are stored in `/home/l0n3/bugbounty/<target>/`:

| File | Description |
|------|-------------|
| `alive_subs.txt` | Live subdomains |
| `alive_js_files.txt` | Active JavaScript files |
| `extracted_urls.txt` | URLs/endpoints extracted from JS files |
| `js_secrets.txt` | API keys and secrets with source files |
| `resumen.txt` | Comprehensive text report |
| `bbrecon_report.html` | Dark mode HTML report |

## 🔑 Secret Detection

The framework detects various types of API keys and secrets:

- **🔥 Firebase**: `AIza[A-Za-z0-9_-]{35}`
- **💳 Stripe**: `sk_[A-Za-z0-9]{48}`, `pk_[A-Za-z0-9]{48}`
- **🐙 GitHub**: `ghp_[A-Za-z0-9]{36}`, `gho_[A-Za-z0-9]{36}`
- **💬 Slack**: `xoxb-`, `xoxp-`, `xoxa-`, `xoxr-`
- **☁️ AWS**: `AKIA[0-9A-Z]{16,20}`, `ASIA[0-9A-Z]{16,20}`
- **🔍 Google OAuth**: `ya29.`, `1//[0-9A-Za-z_-]{35}`

Example output:
```
[FIREBASE] [main.js] AIzaSyDuP6W66GAC2Gad1W2mSQd**************
[STRIPE_SECRET] [checkout.js] sk_live_4eC39HqLyjWDarj**************
```

## 📱 Telegram Notifications

Real-time notifications include:

- **🚀 Start**: When reconnaissance begins
- **✅ Phase Complete**: Discovery, crawling, analysis completion
- **📊 Final Report**: Summary with file attachments
- **❌ Errors**: Critical failures and warnings

Example notifications:
```
🚀 bbrecon started for example.com
✅ Discovery completed: 26 subdomains found
✅ JS Analysis completed: 2 secrets found
📄 [Document] resumen.txt
📄 [Document] bbrecon_report.html
```

## 🎨 Rate Limiting & Stealth

### Conservative Configuration
- **Katana**: 150 req/min, 2s delay, 2 threads
- **JS Downloads**: 3-second delays between files
- **GAU**: 2 threads maximum
- **No aggressive scanning**: No nuclei or port scanning

### Designed for Bug Bounty
- Respects rate limits to avoid detection
- Non-intrusive reconnaissance approach
- Focus on passive information gathering
- Stealth-first methodology

## 🌙 HTML Reports

Beautiful dark mode reports featuring:

- **📊 Statistics Dashboard**: Live counts and metrics
- **🔑 Secret Findings**: Organized by type with source files
- **🔗 Extracted URLs**: All discovered endpoints
- **🌐 Live Subdomains**: Clickable subdomain list
- **📜 JavaScript Files**: Direct links to analyzed files
- **📱 Responsive Design**: Works on all devices

## 🔧 Advanced Configuration

### Custom Rate Limits

Modify in `bbrecon.sh`:
```bash
# Katana settings
katana -depth 3 -c 2 -delay 2

# Download delays
sleep 3  # Between JS file downloads

# GAU threads
gau --threads 2
```

### Adding Custom Patterns

Add to secret detection in `run_js_analysis()`:
```bash
# Custom API pattern
grep -Eho "custom_api_[A-Za-z0-9]{32}" | while read -r secret; do
    echo "[CUSTOM_API] [$js_filename] $secret" >> "$secrets_found"
done
```

## 🐛 Troubleshooting

### Common Issues

1. **Tools not found**:
```bash
# Verify tools are in PATH
which subfinder httpx katana gau
```

2. **Telegram not working**:
```bash
# Test Telegram configuration
cd /home/l0n3/bbrecon
source .env && source utils/telegram.sh && send_message "Test"
```

3. **No secrets found**:
   - Check if JS files are being downloaded
   - Verify grep patterns are working
   - Look at `alive_js_files.txt` for discovered files

4. **Katana failing**:
   - Check delay syntax (should be `-delay 2`, not `-delay 2s`)
   - Verify subdomain list exists and has content

### Debug Mode

Enable verbose logging:
```bash
# Edit bbrecon.sh and add at top
set -x  # Enable debug mode
```

## 📋 Best Practices

1. **Always use rate limiting**: Default settings are conservative for good reason
2. **Manual verification**: Always manually verify secret findings
3. **Responsible testing**: Only test domains you have permission to test
4. **Regular updates**: Keep tools updated for best results
5. **Secure storage**: Never commit .env files or findings to public repos

## 🔐 Security Considerations

- **🔒 Secure .env**: Add to .gitignore, never commit tokens
- **🤖 Dedicated bots**: Use separate Telegram bots per project
- **🔄 Token rotation**: Regularly rotate API tokens
- **📊 Output review**: Check reports for sensitive data before sharing

## 📚 Example Session

```bash
# 1. Setup
cd /home/l0n3/bbrecon
cp env.example .env
nano .env  # Configure Telegram tokens

# 2. Run reconnaissance
bbrecon -t example.com

# 3. Review results
cd /home/l0n3/bugbounty/example.com
cat resumen.txt
cat js_secrets.txt

# 4. Open HTML report
firefox bbrecon_report.html
```

## 🚀 Recent Updates

- **v2.0**: Complete rewrite with stealth focus
- **Secret Detection**: Precise patterns for major API providers
- **Dark Mode Reports**: Beautiful HTML reports
- **Rate Limiting**: Conservative approach for bug bounty
- **File Organization**: Cleaner output structure
- **Telegram Integration**: Real-time progress updates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with rate limiting
4. Ensure stealth compatibility
5. Submit a pull request

## 📜 License

This project is licensed under the GPL-3.0 License.

## ⚠️ Disclaimer

This tool is for authorized security testing purposes only. Users are responsible for:
- Obtaining proper authorization before testing
- Complying with applicable laws and regulations
- Using rate limiting to avoid service disruption
- Following responsible disclosure practices

## 🙋‍♂️ Support

For issues and questions:
1. Check the troubleshooting section
2. Review tool installation
3. Test Telegram configuration
4. Create an issue with logs

---

**Happy Bug Hunting! 🎯🔍**