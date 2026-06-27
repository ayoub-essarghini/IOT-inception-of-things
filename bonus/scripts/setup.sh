#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BONUS_DIR="$ROOT_DIR/bonus"
WORK_DIR="$BONUS_DIR/.work"
GITLAB_NAMESPACE="gitlab"
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
CLUSTER_NAME="dev-cluster"
# GitLab CE rejects weak/forbidden passwords (e.g. anything containing the
# username "root"), which makes gitlab-ctl reconfigure fail. Use a strong,
# word-free default so the initial admin account is created successfully.
GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-Xk7q-Mp42-Zv9t-Rn83}"
GITLAB_PROJECT="playground"
GITLAB_TOKEN_NAME="iot-argocd-token"
GITLAB_TOKEN="${GITLAB_TOKEN:-iot-root-token-424242}"
GITLAB_WEB_PORT="${GITLAB_WEB_PORT:-8081}"
PLAYGROUND_PORT="${PLAYGROUND_PORT:-8888}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_dependencies() {
  if ! command -v docker >/dev/null 2>&1; then
    sudo_cmd apt update -y
    sudo_cmd apt install -y docker.io curl wget git ca-certificates
  else
    sudo_cmd apt install -y curl wget git ca-certificates >/dev/null 2>&1 || true
  fi

  sudo_cmd systemctl start docker 2>/dev/null || true
  sudo_cmd systemctl enable docker 2>/dev/null || true

  if ! command -v k3d >/dev/null 2>&1; then
    sudo_cmd wget https://github.com/rancher/k3d/releases/download/v5.8.3/k3d-linux-amd64 -O /usr/local/bin/k3d
    sudo_cmd chmod +x /usr/local/bin/k3d
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo_cmd install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
  fi
}

install_helm() {
  if command -v helm >/dev/null 2>&1; then
    return
  fi
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

wait_for_gitlab() {
  echo "Waiting for GitLab pods to be ready. This can take several minutes..."
  kubectl wait --for=condition=Ready pods -n "$GITLAB_NAMESPACE" --all --timeout=1200s
}

start_port_forward() {
  local namespace="$1"
  local service="$2"
  local local_port="$3"
  local remote_port="$4"

  pkill -f "kubectl.*port-forward.*${local_port}:${remote_port}" 2>/dev/null || true
  kubectl -n "$namespace" port-forward "svc/$service" \
    "${local_port}:${remote_port}" --address 0.0.0.0 >/tmp/iot-${service}-${local_port}.log 2>&1 &
  sleep 4
}

ensure_base_cluster() {
  need_cmd docker
  need_cmd k3d
  need_cmd kubectl

  if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "Cluster '$CLUSTER_NAME' already exists."
  else
    k3d cluster create "$CLUSTER_NAME" --agents 2 \
      -p "80:80@loadbalancer" \
      -p "443:443@loadbalancer" \
      -p "30222:30222@loadbalancer"
  fi

  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace "$DEV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace "$GITLAB_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

ensure_argocd() {
  if kubectl get deploy argocd-server -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    echo "Argo CD is already installed."
  else
    kubectl apply -n "$ARGOCD_NAMESPACE" --server-side --force-conflicts \
      -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  fi

  echo "Waiting for Argo CD pods..."
  kubectl wait --for=condition=Ready pods --all -n "$ARGOCD_NAMESPACE" --timeout=600s

  if ! command -v argocd >/dev/null 2>&1; then
    curl -sSL -o /tmp/argocd-linux-amd64 \
      https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    rm -f /tmp/argocd-linux-amd64
  fi

  start_port_forward "$ARGOCD_NAMESPACE" argocd-server 8080 443
  argocd login localhost:8080 --insecure --username admin \
    --password "$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)"
}

install_gitlab() {
  kubectl create secret generic gitlab-root-password \
    -n "$GITLAB_NAMESPACE" \
    --from-literal=password="$GITLAB_ROOT_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -f "$BONUS_DIR/confs/gitlab.yaml"
  kubectl rollout status deployment/gitlab -n "$GITLAB_NAMESPACE" --timeout=1800s
  start_port_forward "$GITLAB_NAMESPACE" gitlab "$GITLAB_WEB_PORT" 80
}

seed_gitlab_project() {
  local gitlab_pod
  gitlab_pod="$(kubectl get pod -n "$GITLAB_NAMESPACE" -l app=gitlab -o jsonpath='{.items[0].metadata.name}')"

  kubectl exec -n "$GITLAB_NAMESPACE" "$gitlab_pod" -- gitlab-rails runner "
    user = User.find_by_username('root')
    project = Project.find_by_full_path('root/${GITLAB_PROJECT}')
    unless project
      Projects::CreateService.new(user, {
        name: '${GITLAB_PROJECT}',
        path: '${GITLAB_PROJECT}',
        namespace_id: user.namespace.id,
        visibility_level: Gitlab::VisibilityLevel::PRIVATE
      }).execute
      # Projects::CreateService#execute returns different shapes across GitLab
      # versions (ServiceResponse vs. the Project itself), so re-fetch the
      # canonical record instead of trusting the return value.
      project = Project.find_by_full_path('root/${GITLAB_PROJECT}')
    end
    raise 'Project root/${GITLAB_PROJECT} was not created' unless project
    # Always (re)create the token so its plaintext matches GITLAB_TOKEN. A token
    # left over from a previous run is found by name but its digest will not match
    # our known value, which breaks the HTTP push and the Argo CD repo secret.
    user.personal_access_tokens.where(name: '${GITLAB_TOKEN_NAME}').delete_all
    token = PersonalAccessToken.new(
      user: user,
      name: '${GITLAB_TOKEN_NAME}',
      scopes: ['api', 'read_repository', 'write_repository'],
      expires_at: 1.year.from_now
    )
    token.set_token('${GITLAB_TOKEN}')
    token.save!
    puts project.http_url_to_repo
  "
}

push_app_to_gitlab() {
  local remote="http://root:${GITLAB_TOKEN}@localhost:${GITLAB_WEB_PORT}/root/${GITLAB_PROJECT}.git"

  rm -rf "$WORK_DIR"

  # Clone the existing repo so re-runs add a fast-forward commit on top of the
  # current history. GitLab auto-protects the default branch and rejects force
  # pushes, but the project owner (root) may push non-force commits. A fresh
  # 'git init' would create an unrelated history and be rejected on re-runs, so
  # we only init when the remote is still empty.
  if git clone "$remote" "$WORK_DIR" 2>/dev/null && \
     git -C "$WORK_DIR" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$WORK_DIR" checkout -B main
  else
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    git -C "$WORK_DIR" init -b main
    git -C "$WORK_DIR" remote add origin "$remote"
  fi

  git -C "$WORK_DIR" config user.email "iot@example.local"
  git -C "$WORK_DIR" config user.name "Inception of Things"

  cp "$ROOT_DIR/p3/app/"*.yaml "$WORK_DIR/"
  git -C "$WORK_DIR" add .
  if ! git -C "$WORK_DIR" diff --cached --quiet; then
    git -C "$WORK_DIR" commit -m "Import part 3 playground app"
  fi
  git -C "$WORK_DIR" push -u origin main

  # The default branch is protected by GitLab's default-branch policy (enforced
  # even without an explicit rule), which blocks every later push including the
  # manual v1->v2 demo. Replace it with a permissive rule that allows developers
  # to push and force-push so the repository can be updated via plain git.
  unprotect_default_branch
}

unprotect_default_branch() {
  local pod
  pod="$(kubectl get pod -n "$GITLAB_NAMESPACE" -l app=gitlab -o jsonpath='{.items[0].metadata.name}')"
  kubectl exec -n "$GITLAB_NAMESPACE" "$pod" -- gitlab-rails runner "
    project = Project.find_by_full_path('root/${GITLAB_PROJECT}')
    root = User.find_by_username('root')
    if project && root
      project.protected_branches.where(name: 'main').destroy_all
      ProtectedBranches::CreateService.new(project, root, {
        name: 'main',
        allow_force_push: true,
        push_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
        merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }]
      }).execute
    end
  "
}

configure_argocd_app() {
  local repo_url="http://gitlab.${GITLAB_NAMESPACE}.svc.cluster.local/root/${GITLAB_PROJECT}.git"

  kubectl create secret generic argocd-local-gitlab-repo \
    -n "$ARGOCD_NAMESPACE" \
    --from-literal=type=git \
    --from-literal=url="$repo_url" \
    --from-literal=username=root \
    --from-literal=password="$GITLAB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl label secret argocd-local-gitlab-repo -n "$ARGOCD_NAMESPACE" \
    argocd.argoproj.io/secret-type=repository --overwrite

  argocd app create playground \
    --repo "$repo_url" \
    --path "." \
    --dest-server "https://kubernetes.default.svc" \
    --dest-namespace "$DEV_NAMESPACE" \
    --revision main \
    --sync-policy automated \
    --self-heal \
    --auto-prune \
    --upsert

  argocd app sync playground
  argocd app wait playground --health --sync --timeout 300
}

open_playground_tunnel() {
  kubectl wait --for=condition=Available deployment/playground -n "$DEV_NAMESPACE" --timeout=180s
  refresh_playground_port_forward
}

refresh_playground_port_forward() {
  pkill -f "kubectl.*port-forward.*${PLAYGROUND_PORT}:8888" 2>/dev/null || true
  kubectl -n "$DEV_NAMESPACE" port-forward svc/playground \
    "${PLAYGROUND_PORT}:8888" --address 0.0.0.0 >/tmp/iot-playground-${PLAYGROUND_PORT}.log 2>&1 &
  sleep 2
}

show_version_change_hint() {
  cat <<EOF

Bonus setup is ready.

GitLab UI:
  http://localhost:${GITLAB_WEB_PORT}
  username: root
  password: ${GITLAB_ROOT_PASSWORD}

Argo CD UI:
  https://localhost:8080

Application:
  http://localhost:${PLAYGROUND_PORT}

Repository used by Argo CD:
  http://gitlab.${GITLAB_NAMESPACE}.svc.cluster.local/root/${GITLAB_PROJECT}.git

To demonstrate the Part 3 version change with local GitLab:
  cd ${WORK_DIR}
  sed -i 's/wil42\\/playground:v1/wil42\\/playground:v2/' deployment.yaml
  git add deployment.yaml
  git commit -m "Update playground version"
  git push
  argocd app wait playground --health --sync --timeout 300
  # Restart the port-forward after pod recreation:
  bash bonus/scripts/setup.sh --refresh-port-forward

EOF
}

run_full_setup() {
  install_dependencies
  ensure_base_cluster
  ensure_argocd
  install_gitlab
  seed_gitlab_project
  push_app_to_gitlab
  configure_argocd_app
  open_playground_tunnel
  show_version_change_hint
}

usage() {
  cat <<EOF
Usage: bash bonus/scripts/setup.sh [command]

Commands:
  (no argument)            Run the full bonus setup pipeline.
  --refresh-port-forward   Restart the playground port-forward after a pod
                           recreation (e.g. an Argo CD version sync).
  -h, --help               Show this help message.
EOF
}

main() {
  case "${1:-}" in
    "")
      run_full_setup
      ;;
    --refresh-port-forward)
      refresh_playground_port_forward
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
