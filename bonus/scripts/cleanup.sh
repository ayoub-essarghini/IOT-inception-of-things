#!/usr/bin/env bash

set -euo pipefail

echo "Stopping port-forward processes..."
pkill -f "kubectl.*port-forward" 2>/dev/null || true

echo "Deleting Argo CD application if it exists..."
if command -v argocd >/dev/null 2>&1; then
  argocd app delete playground --yes 2>/dev/null || true
fi

echo "Deleting GitLab release and namespace..."
kubectl delete namespace gitlab --ignore-not-found=true 2>/dev/null || true
kubectl delete secret argocd-local-gitlab-repo -n argocd --ignore-not-found=true 2>/dev/null || true

echo "Bonus cleanup finished."
