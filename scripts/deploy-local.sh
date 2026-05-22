#!/usr/bin/env bash
# deploy-local.sh — build Lambda packages and deploy infrastructure locally
set -euo pipefail
sed -i 's/\r//' "$0" 2>/dev/null || true   # fix CRLF if edited on Windows

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Paths ────────────────────────────────────────────────────
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SRC_DIR="$TERRAFORM_DIR/foundation/src"
BUILD_DIR="$TERRAFORM_DIR/foundation/build"

# Load .env from project root if present
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +o allexport
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
info() { echo -e "${CYAN}→${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
die()  { echo -e "${RED}✗ ERROR:${RESET} $1" && exit 1; }
hr()   { echo -e "\n${BOLD}── $1 ──────────────────────────────${RESET}"; }

echo -e "\n${BOLD}rag-on-bedrock · local deploy${RESET}\n"

# ─────────────────────────────────────────────────────────────
# 1. Prerequisites
# ─────────────────────────────────────────────────────────────
hr "1 / 4  Prerequisites"

command -v docker    &>/dev/null || die "Docker is not installed or not running"
command -v terraform &>/dev/null || die "Terraform is not installed. Run bootstrap.sh first"
command -v aws       &>/dev/null || die "AWS CLI is not installed. Run bootstrap.sh first"
ok "Docker, Terraform and AWS CLI are available"

aws sts get-caller-identity &>/dev/null \
  || die "AWS credentials not configured. Run 'aws configure' or check your environment"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ok "AWS credentials OK  (account: ${ACCOUNT_ID})"

[[ -n "${COGNITO_USER_NAME:-}"     ]] || die "COGNITO_USER_NAME is not set (add it to .env or export it)"
[[ -n "${COGNITO_USER_PASSWORD:-}" ]] || die "COGNITO_USER_PASSWORD is not set (add it to .env or export it)"
ok "Cognito admin credentials loaded"

# ─────────────────────────────────────────────────────────────
# 2. Build Lambda packages
# ─────────────────────────────────────────────────────────────
hr "2 / 4  Build Lambda packages"

build_lambda() {
  local name=$1
  local requirements=$2
  shift 2
  local sources=("$@")

  local build_dir="$BUILD_DIR/$name"
  info "Building $name..."
  info "  Deps   → $build_dir"

  mkdir -p "$BUILD_DIR"

  docker run --rm \
    -v "$SRC_DIR:/src" \
    -v "$BUILD_DIR:/build" \
    public.ecr.aws/sam/build-python3.14 \
    bash -c "rm -rf /build/$name && pip install -qq -r /src/$requirements -t /build/$name && chown -R $(id -u):$(id -g) /build/$name"

  for src in "${sources[@]}"; do
    info "  Copying $src → $build_dir/$src"
    cp "$SRC_DIR/$src" "$build_dir/"
  done

  local zip_path="$BUILD_DIR/$name.zip"
  file_count=$(find "$build_dir" -type f | wc -l | tr -d ' ')
  info "  Zipping → $zip_path  ($file_count files)"
  rm -f "$zip_path"
  (cd "$build_dir" && zip -r "$zip_path" .) > /dev/null
  ok "$name.zip ready  ($(du -sh "$zip_path" | cut -f1))"
}

mkdir -p "$BUILD_DIR"

build_lambda extractor  requirements-extractor.txt  extractor.py
build_lambda splitter   requirements-splitter.txt   splitter.py
build_lambda embedder   requirements-embedder.txt   embedder.py
build_lambda query     requirements-query.txt     query.py prompt.txt

# ─────────────────────────────────────────────────────────────
# 3. Terraform plan
# ─────────────────────────────────────────────────────────────
hr "3 / 4  Terraform plan"

info "Initialising Terraform..."
terraform -chdir="$TERRAFORM_DIR" init -upgrade -input=false > /dev/null
ok "Terraform initialised"

info "Running plan..."
terraform -chdir="$TERRAFORM_DIR" plan -input=false \
  -var="admin_email=${COGNITO_USER_NAME}" \
  -var="admin_password=${COGNITO_USER_PASSWORD}"
echo ""

# ─────────────────────────────────────────────────────────────
# 4. Apply
# ─────────────────────────────────────────────────────────────
hr "4 / 4  Terraform apply"

read -rp "$(echo -e "${YELLOW}Apply the plan above? [y/N]:${RESET} ")" confirm
[[ "${confirm,,}" == "y" ]] || { warn "Aborted — no changes were made"; exit 0; }

info "Applying..."
terraform -chdir="$TERRAFORM_DIR" apply -auto-approve -input=false \
  -var="admin_email=${COGNITO_USER_NAME}" \
  -var="admin_password=${COGNITO_USER_PASSWORD}"

# ─────────────────────────────────────────────────────────────
# 5. Generate runbook
# ─────────────────────────────────────────────────────────────
hr "5 / 4  Generating runbook"

CLIENT_ID=$(terraform -chdir="$TERRAFORM_DIR" output -raw cognito_user_pool_client_id 2>/dev/null || echo "<CLIENT_ID>")
API_ENDPOINT=$(terraform -chdir="$TERRAFORM_DIR" output -raw api_endpoint 2>/dev/null | sed 's|/$||' || echo "<API_ENDPOINT>")
BUCKET="future-solutions-dev-ingestion-pdf-${ACCOUNT_ID}"
REGION="eu-west-2"
RUNBOOK="$PROJECT_ROOT/runbook.sh"

cat > "$RUNBOOK" <<RUNBOOK
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ID="${CLIENT_ID}"
API_ENDPOINT="${API_ENDPOINT}"
BUCKET="${BUCKET}"
REGION="${REGION}"
USERNAME="${COGNITO_USER_NAME}"
PASSWORD="${COGNITO_USER_PASSWORD}"
DOCUMENT="${PROJECT_ROOT}/test/test-document.pdf"

SESSION=\$(aws cognito-idp initiate-auth \\
  --auth-flow USER_PASSWORD_AUTH \\
  --auth-parameters USERNAME=\${USERNAME},PASSWORD=\${PASSWORD} \\
  --client-id \${CLIENT_ID} --region \${REGION} \\
  --query 'Session' --output text 2>/dev/null || echo "")

if [[ -n "\${SESSION}" && "\${SESSION}" != "None" ]]; then
  aws cognito-idp respond-to-auth-challenge \\
    --client-id \${CLIENT_ID} \\
    --challenge-name NEW_PASSWORD_REQUIRED \\
    --challenge-responses USERNAME=\${USERNAME},NEW_PASSWORD=\${PASSWORD} \\
    --session "\${SESSION}" --region \${REGION} > /dev/null
fi

TOKEN=\$(aws cognito-idp initiate-auth \\
  --auth-flow USER_PASSWORD_AUTH \\
  --auth-parameters USERNAME=\${USERNAME},PASSWORD=\${PASSWORD} \\
  --client-id \${CLIENT_ID} --region \${REGION} \\
  --query 'AuthenticationResult.IdToken' --output text)

aws s3 cp "\${DOCUMENT}" s3://\${BUCKET}/ --region \${REGION}

echo ""
echo "── PowerShell snippet (paste into PowerShell) ───────────────"
RUNBOOK

cat >> "$RUNBOOK" <<'PWSH'
printf '%s\n' '$auth = aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=__USERNAME__,PASSWORD=__PASSWORD__ --client-id __CLIENT_ID__ --region __REGION__ | ConvertFrom-Json'
printf '%s\n' '$token = "Bearer " + $auth.AuthenticationResult.IdToken'
printf '%s\n' '$token = $token -replace "`r`n","" -replace "`n","" -replace "`r",""'
printf '%s\n' '(Invoke-RestMethod -Method POST -Uri "__API_ENDPOINT__/query" -Headers @{"Authorization"=$token;"Content-Type"="application/json"} -Body '"'"'{"question": "What does the document say about AFT?"}'"'"').answer'
PWSH

sed -i \
  "s|__USERNAME__|${COGNITO_USER_NAME}|g;
   s|__PASSWORD__|${COGNITO_USER_PASSWORD}|g;
   s|__CLIENT_ID__|${CLIENT_ID}|g;
   s|__REGION__|${REGION}|g;
   s|__API_ENDPOINT__|${API_ENDPOINT}|g" "$RUNBOOK"

chmod +x "$RUNBOOK"
ok "Runbook generated → $RUNBOOK"

# ─────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}Deploy complete!${RESET}\n"
