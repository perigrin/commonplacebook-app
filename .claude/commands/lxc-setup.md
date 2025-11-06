# LXC Development Container Setup

You are helping to set up a new LXC container for development work. Please
create and configure a container with the following specifications:

## Container Requirements

**Base Configuration:**
- Use Ubuntu 24.04 (default `ubuntu:` image)
- Container name: $ARGUMENTS (if no arguments provided, ask for container name)
- Location: Remote datacenter host
- Isolation: Fully isolated containers (no host directory sharing)

**User Setup:**
- Create user account: `perigrin`
- Configure sudo access without password prompt
- Set up SSH access with GitHub public keys (https://github.com/perigrin.keys)
- Set up proper shell environment with oh-my-zsh

**Package Installation:**
Execute these steps in order:
1. Update system packages (`apt update && apt upgrade`)
2. Install base packages: `build-essential git curl wget vim nano htop tree jq zsh tmux`
3. Install Go Version Manager (gvm):
   - Install dependencies: `bison`
   - Download and install gvm as perigrin user
   - Install and set default Go version (1.21.5 or latest stable)
4. Install Claude Code using the official installer
5. Install Homebrew for Linux
6. Convert and install packages from any local Brewfile if present

**Network Configuration:**
1. Install Tailscale from official repository
2. Set up temporary DNS configuration (8.8.8.8, 1.1.1.1) during bootstrap
3. Backup original resolv.conf for later restoration

**Development Environment:**
1. Install Atuin shell history tool
2. Configure shell integration for bash and zsh
3. Set up dotfiles using bare git repository approach with backup
4. Install oh-my-zsh for enhanced shell experience
5. Set up Vim with Vundle plugin manager
6. Install Tmux Plugin Manager (TPM)

## Implementation Steps

Please execute these commands to set up the container:

```bash
# Create and start container
lxc launch ubuntu:24.04 CONTAINER_NAME
sleep 10

# Wait for network connectivity
while ! lxc exec CONTAINER_NAME -- ping -c 1 8.8.8.8 &>/dev/null; do
    echo "Waiting for network..."
    sleep 2
done

# Update system
lxc exec CONTAINER_NAME -- apt update
lxc exec CONTAINER_NAME -- apt upgrade -y

# Install base packages
lxc exec CONTAINER_NAME -- apt install -y build-essential git curl wget vim nano htop tree jq bison zsh tmux

# Create perigrin user
lxc exec CONTAINER_NAME -- useradd -m -s /bin/zsh perigrin
lxc exec CONTAINER_NAME -- usermod -aG sudo perigrin
lxc exec CONTAINER_NAME -- bash -c "echo 'perigrin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/perigrin"

# Set up SSH access with GitHub keys
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    curl -fsSL https://github.com/perigrin.keys > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
'

# Install gvm as perigrin user
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash
    source ~/.gvm/scripts/gvm
    gvm install go1.21.5 --default
'

# Install Claude Code
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    curl -fsSL https://claude.ai/api/cli/install.sh | sh
'

# Install Tailscale
lxc exec CONTAINER_NAME -- bash -c '
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.list | tee /etc/apt/sources.list.d/tailscale.list
    apt update
    apt install -y tailscale
'

# Install Atuin
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    curl --proto "=https" --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    echo "eval \"\$(atuin init bash)\"" >> ~/.bashrc
    echo "eval \"\$(atuin init zsh)\"" >> ~/.zshrc 2>/dev/null || true
'

# Install GitHub CLI
lxc exec CONTAINER_NAME -- bash -c '
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update
    apt install gh -y
'

# Install Homebrew for Linux
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> ~/.bashrc
    echo "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> ~/.zshrc
'

# Install oh-my-zsh
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
'

# Install Vim plugins with Vundle
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
'

# Install Tmux Plugin Manager
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- bash -c '
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
'

# Set up temporary DNS
lxc exec CONTAINER_NAME -- bash -c '
    cp /etc/resolv.conf /etc/resolv.conf.backup
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
'
```

## Post-Setup Manual Steps

After the automated setup completes, provide these instructions:

**Connect to Container:**
```bash
lxc exec CONTAINER_NAME --user 1000 --group 1000 --env HOME="/home/perigrin" -- zsh
```

**Configure Tailscale:**
```bash
sudo tailscale up
```

**Set up Atuin (requires 1Password for sync key):**
```bash
atuin login -u <username>
atuin sync
```

**Set up Dotfiles:**
```bash
# First authenticate GitHub CLI (required for private repos)
gh auth login

# Clone dotfiles as bare repository
mkdir -p $HOME/.config
gh repo clone perigrin/dotfiles $HOME/.config/dotfiles -- --bare

# Set up config function
function config {
   /usr/bin/git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME $@
}

# Backup any existing dotfiles
mkdir -p .config-backup
config checkout
if [ $? = 0 ]; then
  echo "Checked out config.";
else
    echo "Backing up pre-existing dot files.";
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I% mv % .config-backup/%
fi;

# Checkout dotfiles
config checkout
config config status.showUntrackedFiles no

# Install Vim plugins
vim +PluginInstall +qall

# Install Homebrew packages from global Brewfile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew bundle install --global
```

**Note:** Your dotfiles now include `.claude/CLAUDE.md`, `.claude/commands/`, and `.claude/skills/` which will sync automatically with the above checkout.

**Authenticate Claude Code:**
```bash
# Set up Claude Code authentication
claude auth login

# Verify configuration synced from dotfiles
ls -la ~/.claude/CLAUDE.md ~/.claude/commands/ ~/.claude/skills/
```

**Restore DNS (after Tailscale is working):**
```bash
sudo cp /etc/resolv.conf.backup /etc/resolv.conf
```

## Verification

Check the container status and display connection information:
```bash
lxc list CONTAINER_NAME
```

**SSH Access:**
You can now SSH directly to the container as the perigrin user using your private key:
```bash
ssh perigrin@<container-ip>
```

Replace `CONTAINER_NAME` with the actual container name provided in $ARGUMENTS.
