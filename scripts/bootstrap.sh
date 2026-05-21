#!/usr/bin/env bash
# bootstrap.sh — one-time project setup for WSL2 + ZSH
set -euo pipefail
sed -i 's/\r//' "$0" 2>/dev/null || true   # fix CRLF if edited on Windows

# colours
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
info() { echo -e "${CYAN}→${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
die()  { echo -e "${RED}✗ ERROR:${RESET} $1" && exit 1; }
hr()   { echo -e "\n${BOLD}── $1 ──────────────────────────────${RESET}"; }

echo -e "\n${BOLD}rag-on-bedrock-aft · bootstrap${RESET}\n"

# ─────────────────────────────────────────────────────────────
# 1. Confirm WSL2
# ─────────────────────────────────────────────────────────────
hr "1 / 8  Environment"

grep -qi microsoft /proc/version 2>/dev/null \
  || die "Not running inside WSL. This script is WSL2-only."
ok "WSL2 detected"

# Warn if project is on Windows filesystem (breaks pyenv)
[[ "$(pwd)" == /mnt/* ]] && die \
  "Project is on /mnt/ (Windows filesystem). Move it to the WSL filesystem first:
  cp -r $(pwd) ~/projects/rag-on-bedrock-aft
  cd ~/projects/rag-on-bedrock-aft && bash bootstrap.sh"
ok "Project is on WSL filesystem"

# ─────────────────────────────────────────────────────────────
# 2. System packages
# ─────────────────────────────────────────────────────────────
hr "2 / 8  System packages"

sudo apt-get update -q
sudo apt-get install -yq \
  zsh curl wget git unzip zip dos2unix \
  make build-essential \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  libncursesw5-dev xz-utils libffi-dev liblzma-dev \
  gnupg software-properties-common lsb-release 2>/dev/null
ok "System packages ready"

# Fix line endings on all project files
find . \( -name "*.sh" -o -name "*.tf" -o -name "*.py" -o -name "*.txt" \
          -o -name "Makefile" -o -name "*.md" \) \
  -not -path "./.venv/*" -not -path "./.git/*" \
  | xargs dos2unix -q 2>/dev/null || true
ok "Line endings normalised (CRLF → LF)"

# ─────────────────────────────────────────────────────────────
# 3. AWS CLI
# ─────────────────────────────────────────────────────────────
hr "3 / 8  AWS CLI"

if command -v aws &>/dev/null; then
  ok "AWS CLI $(aws --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) already installed"
else
  info "Installing AWS CLI v2..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/awscli
  sudo /tmp/awscli/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/awscli
  ok "AWS CLI $(aws --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) installed"
fi

# ─────────────────────────────────────────────────────────────
# 4. Terraform
# ─────────────────────────────────────────────────────────────
hr "4 / 8  Terraform"

if command -v terraform &>/dev/null; then
  ok "Terraform $(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') already installed"
else
  info "Installing Terraform (latest from HashiCorp apt repo)..."
  wget -qO- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
  sudo apt-get update -q && sudo apt-get install -yq terraform 2>/dev/null
  ok "Terraform $(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') installed"
fi

# ─────────────────────────────────────────────────────────────
# 5. Python via pyenv  (latest 3.12.x)
# ─────────────────────────────────────────────────────────────
hr "5 / 8  Python 3.12 (latest) via pyenv"

export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"

if ! command -v pyenv &>/dev/null; then
  info "Installing pyenv..."
  curl -fsSL https://pyenv.run | bash
  eval "$(${PYENV_ROOT}/bin/pyenv init -)"

  # Add pyenv to .zshrc if not already there
  if ! grep -q "pyenv init" "${HOME}/.zshrc" 2>/dev/null; then
    cat >> "${HOME}/.zshrc" << 'EOF'

# pyenv
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
EOF
    ok "pyenv added to ~/.zshrc"
  fi
fi
eval "$(pyenv init -)" 2>/dev/null || true

# Pick the latest stable 3.12.x available in pyenv
PYTHON_VERSION=$(pyenv install --list | grep -E "^\s+3\.12\.[0-9]+$" | tail -1 | tr -d ' ')
[[ -z "$PYTHON_VERSION" ]] && die "Could not find Python 3.12.x in pyenv list"
info "Latest Python 3.12.x: ${PYTHON_VERSION}"

pyenv versions | grep -q "${PYTHON_VERSION}" \
  && ok "Python ${PYTHON_VERSION} already installed" \
  || (info "Installing Python ${PYTHON_VERSION} (~2-3 min)..." && pyenv install "${PYTHON_VERSION}")

pyenv local "${PYTHON_VERSION}"
ok "Active: $(python --version)"

# ─────────────────────────────────────────────────────────────
# 6. Virtual environment
# ─────────────────────────────────────────────────────────────
hr "6 / 8  Virtual environment"

if [[ ! -d ".venv" ]]; then
  python -m venv .venv
  ok ".venv created"
else
  ok ".venv already exists"
fi

source .venv/bin/activate
pip install --upgrade pip -q
ok "pip $(pip --version | cut -d' ' -f2)  |  $(python --version)"

info "Installing project dependencies (latest versions)..."
pip install --upgrade -r requirements-dev.txt -q
ok "All packages installed"

# ─────────────────────────────────────────────────────────────
# 7. Terraform variables
# ─────────────────────────────────────────────────────────────
hr "7 / 8  Terraform variables"

if aws sts get-caller-identity &>/dev/null; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ok "AWS credentials OK  (account: ${ACCOUNT_ID})"

  if [[ ! -f "terraform/foundation/terraform.tfvars" ]]; then
    cp terraform/foundation/example.tfvars terraform/foundation/terraform.tfvars
    sed -i "s/123456789012/${ACCOUNT_ID}/" terraform/foundation/terraform.tfvars
    ok "terraform.tfvars created with your account ID"
  else
    ok "terraform.tfvars already exists"
  fi
else
  warn "AWS credentials not found — skipping terraform.tfvars"
  warn "Run 'aws configure' then copy example.tfvars manually"
fi

# ─────────────────────────────────────────────────────────────
# Automatically load .venv when entering project dir
# ─────────────────────────────────────────────────────────────
hr "8 / 8   direnv"

if command -v direnv &>/dev/null; then
  ok "direnv already installed"
else
  sudo apt-get install -yq direnv 2>/dev/null
  ok "direnv installed"
fi

if ! grep -q "direnv hook zsh" "${HOME}/.zshrc"; then
  echo 'eval "$(direnv hook zsh)"' >> "${HOME}/.zshrc"
  ok "direnv hook added to ~/.zshrc"
else
  ok "direnv hook already in ~/.zshrc"
fi

if [[ ! -f ".env" ]]; then
  cat > .env << 'EOF'
AWS_ACCESS_KEY_ID=replace-me
AWS_SECRET_ACCESS_KEY=replace-me
AWS_DEFAULT_REGION=eu-west-2
EOF
  ok ".env created — fill in your credentials"
else
  ok ".env already exists"
fi

direnv allow 2>/dev/null || true
ok "direnv allowed for this directory"

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}All done!${RESET}\n"
echo -e "  Python    $(python --version)"
echo -e "  Terraform $(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo -e "  AWS CLI   $(aws --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo ""
echo -e "${BOLD}Next:${RESET}"
echo -e "  1.  exec zsh                         ← reload shell so pyenv works"
echo -e "  2.  source .venv/bin/activate         ← activate venv in new terminals"
echo -e "  3.  Enable Bedrock model access:      ← do this before terraform apply"
echo -e "      https://eu-west-1.console.aws.amazon.com/bedrock/home#/modelaccess"
echo -e "      → Titan Embeddings V2  +  Claude 3 Haiku"
echo -e "  4.  make deploy-foundation"
echo ""