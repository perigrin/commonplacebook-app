---
name: Configuration Sync
description: Bare git repository pattern for syncing dotfiles and Claude Code configs across machines without symlinks
when_to_use: Managing dotfiles (.zshrc, .vimrc, .tmux.conf, .gitconfig) across multiple machines. Syncing Claude Code configuration (.claude/CLAUDE.md, .claude/commands/). When you want to track configuration files in git without maintaining symlinks. Setting up new development machines with consistent environment.
version: 1.0.0
languages: all
---

# Configuration Sync

## Overview

Use a **bare git repository** with `$HOME` as the working tree to track dotfiles naturally - no symlinks needed.

**Core principle:** Files live where they belong (`~/.zshrc`, `~/.vimrc`) while git metadata lives in `~/.config/dotfiles`.

## When to Use

**Use this pattern when:**
- Managing configuration files across multiple machines
- Syncing dotfiles (.zshrc, .vimrc, .tmux.conf, .gitconfig, .claude/)
- Setting up consistent development environments
- You want version control without symlink management overhead

**Don't use for:**
- Application data that changes frequently
- Machine-specific secrets (use separate, untracked files)
- Binary files or large media

## Core Pattern

**❌ Old way (symlinks):**
```bash
~/dotfiles/.zshrc  →  ln -s ~/dotfiles/.zshrc ~/.zshrc
# Requires manual symlink management
```

**✅ Bare repo pattern:**
```bash
# Files live naturally in $HOME
# Git metadata in ~/.config/dotfiles (bare repo)
# No symlinks needed
```

## Quick Reference

| Operation | Command |
|-----------|---------|
| **Setup new machine** | `gh repo clone user/dotfiles ~/.config/dotfiles -- --bare` |
| **Configure alias** | `alias config='git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME'` |
| **Hide untracked files** | `config config status.showUntrackedFiles no` |
| **Check status** | `config status` |
| **Add dotfile** | `config add .zshrc` |
| **Commit** | `config commit -m "Update zsh config"` |
| **Push** | `config push` |
| **Sync from remote** | `config pull` or `update` (if configured) |

## Implementation

### Initial Setup (First Machine)

```bash
# Initialize bare repo
git init --bare $HOME/.config/dotfiles

# Create config alias
alias config='git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME'

# Hide untracked files (crucial!)
config config status.showUntrackedFiles no

# Add dotfiles
config add .zshrc .vimrc .tmux.conf .gitconfig

# Add Claude Code configuration
config add .claude/CLAUDE.md
config add .claude/commands/

# Commit and push
config commit -m "Initial dotfiles"
config remote add origin git@github.com:username/dotfiles.git
config push -u origin main
```

### Bootstrap New Machine

```bash
# Clone as bare repository
gh repo clone username/dotfiles $HOME/.config/dotfiles -- --bare

# Define config alias temporarily
alias config='git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME'

# Back up existing files (if conflicts occur)
mkdir -p .config-backup
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | \
  xargs -I{} mv {} .config-backup/{}

# Checkout dotfiles
config checkout

# Hide untracked files
config config status.showUntrackedFiles no

# Make alias permanent (add to .zshrc or .bashrc)
echo "alias config='git --git-dir=\$HOME/.config/dotfiles --work-tree=\$HOME'" >> ~/.zshrc
```

### Daily Workflow

```bash
# Edit any dotfile in place
vim ~/.zshrc

# Stage, commit, push (just like regular git!)
config add .zshrc
config commit -m "Add new alias"
config push

# On other machines
config pull  # or just: update
```

### Adding Claude Code Configs

```bash
# Claude Code configs are just regular dotfiles
config add .claude/CLAUDE.md
config add .claude/commands/status-check.md
config commit -m "Update Claude commands"
config push
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| **Using regular git commands** | Use `config` alias, not `git` |
| **Forgetting status.showUntrackedFiles no** | Run `config config status.showUntrackedFiles no` or `config status` will show all $HOME files |
| **Tracking sensitive files** | Add to `.gitignore` in $HOME, keep secrets in separate untracked files |
| **Regular clone instead of bare** | Must use `-- --bare` flag when cloning |
| **Symlinks approach** | Don't create symlinks - files live naturally in $HOME |
| **$HOME not tracked directly** | The whole $HOME is the working tree - selectively add files you want tracked |

## Why Not Symlinks?

**Bare repo advantages:**
- ✅ No symlink management or breakage
- ✅ Files in natural locations
- ✅ Simple git operations via alias
- ✅ Easy to add new files
- ✅ Cross-platform compatible

**Symlinks disadvantages:**
- ❌ Manual link creation and maintenance
- ❌ Links can break if repo moves
- ❌ Extra directory (~/dotfiles) to manage
- ❌ Two-step process to add files
- ❌ Complex bootstrap scripts

## Handling Conflicts

If existing dotfiles conflict during checkout:

```bash
# Option 1: Backup conflicting files
mkdir -p .config-backup
mv ~/.zshrc .config-backup/.zshrc
config checkout

# Option 2: Automate with script (in bootstrap)
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | \
  xargs -I{} mv {} .config-backup/{}
```

## Automation

Create an `update` alias to sync and update tools:

```bash
# In .zshrc or .bashrc
alias update='config pull && vim +PluginUpdate +qall'

# Usage
update  # Pulls latest dotfiles AND updates vim plugins
```

Customize this to update any tools configured by your dotfiles (vim, tmux, etc.).

## Bootstrap Script

For one-command setup, create `.config/install.sh` in your repo:

```bash
#!/bin/bash
# Clone bare repo
gh repo clone username/dotfiles $HOME/.config/dotfiles -- --bare

# Setup config alias
alias config='git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME'

# Backup conflicts
mkdir -p .config-backup
config checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | \
  xargs -I{} mv {} .config-backup/{}

# Checkout dotfiles
config checkout
config config status.showUntrackedFiles no

# Run post-install (vim plugins, etc.)
vim +PluginInstall +qall
```

Then on new machines: `curl https://raw.githubusercontent.com/username/dotfiles/main/.config/install.sh | bash`

## Migrating from Symlinks

If you have existing symlinks setup:

```bash
# Remove symlinks and copy files back
cd ~/dotfiles
for file in *; do
    rm ~/$file  # Remove symlink
    cp $file ~/$file  # Copy file to home
done

# Initialize bare repo
git init --bare $HOME/.config/dotfiles
alias config='git --git-dir=$HOME/.config/dotfiles --work-tree=$HOME'
config config status.showUntrackedFiles no

# Add files from $HOME (not ~/dotfiles)
config add ~/.zshrc ~/.vimrc ~/.tmux.conf
config commit -m "Migrate from symlinks to bare repo"
config remote add origin <your-repo-url>
config push -u origin main

# Clean up old repo
rm -rf ~/dotfiles
```

## Sensitive Data

**Never track secrets in git.** Use separate files:

```bash
# In .zshrc
[ -f ~/.secrets ] && source ~/.secrets

# Create ~/.secrets (untracked)
echo "export API_KEY=..." > ~/.secrets
chmod 600 ~/.secrets

# Ensure it's ignored
echo ".secrets" >> ~/.gitignore
config add .gitignore
```

## Addressing Common Concerns

**"Bare repos seem complicated"**
- Reality: One-time 5-minute setup, then it's just git
- The `config` alias makes it identical to regular git workflow

**"I might accidentally track sensitive files"**
- Reality: You explicitly `config add` each file - nothing tracked by accident
- Plus `status.showUntrackedFiles no` prevents $HOME noise

**"What if I forget which files are tracked?"**
- Reality: `config status` shows exactly what's tracked, just like git

**"Symlinks are more explicit about what's managed"**
- Reality: Bare repo is equally explicit via `config status`
- Without the overhead of maintaining symlinks

**"I already have symlinks working"**
- Reality: See "Migrating from Symlinks" section - 10-minute migration
