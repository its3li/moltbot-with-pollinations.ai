# Moltbot Custom — AWS Edition 🚀

This is a customized version of Moltbot, optimized for easy deployment on AWS and featuring free, high-performance tools out of the box.

## ✨ Custom Features

I have modified the original Moltbot to make it more accessible and powerful without requiring expensive API keys:

- **Pollinations AI Provider**: Added support for [Pollinations AI](https://pollinations.ai/) as a first-class model provider.
- **Free Web Search (DuckDuckGo)**: Replaced the paid Brave Search API with a free DuckDuckGo HTML scraper.
  - ✅ No API key required.
  - ✅ Enabled by default.
  - ✅ Unlimited free web searching for your agent.
- **AWS Optimized**: Performance tweaks and build bypasses (like `CLAWDBOT_A2UI_SKIP_MISSING`) to ensure stable 24/7 operation on EC2 instances.

---

## ☁️ AWS EC2 Setup (24/7 Guide)

To host this bot on an AWS EC2 instance (Ubuntu 24.04 recommended):

### 1. Requirements
Ensure your instance has at least **20GB of disk space** and **node v22+** installed.

### 2. Installation
```bash
git clone <your-repo-url> moltbot
cd moltbot
pnpm install
```

### 3. Building
Since this version is optimized for server use, use the bypass flag if you are missing UI assets:
```bash
export CLAWDBOT_A2UI_SKIP_MISSING=1 && npm run build
```

### 4. Onboarding
Run the setup wizard to link your Telegram/WhatsApp and select **Pollinations AI** as your model provider:
```bash
node dist/index.js onboard --install-daemon
```

### 5. Keeping it Live 24/7
Use PM2 to ensure the bot never goes down:
```bash
# Start the bot
pm2 start node --name "moltbot" -- dist/index.js gateway

# Set up auto-restart on reboot
pm2 startup
# (Copy and run the command it gives you)

# Save the state
pm2 save
```

---

## 🛠 Usage Commands

- **Check Status**: `pm2 status`
- **View Live Logs**: `pm2 logs moltbot`
- **Change Settings**: `node dist/index.js configure`
- **Wipe Memory**: `node dist/index.js reset --full`
- **Approve Pairing**: `node dist/index.js pairing approve telegram <CODE>`

## 📜 Credits
Based on the original [Moltbot](https://github.com/moltbot/moltbot). Customizations for free search and Pollinations AI integration by Antigravity.
