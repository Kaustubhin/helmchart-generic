#!/usr/bin/env bash
# Renders every chart that depends on platform-common at a given git ref, so the
# library's CI can diff its own change against real consumers before merge.
set -euo pipefail
ref="$1"
worktree=$(mktemp -d)
git worktree add -q --detach "$worktree" "$ref"
trap 'git worktree remove -f "$worktree"' EXIT
for chart in "$worktree"/charts/*/; do
  [[ "$(yq -r .type "$chart/Chart.yaml" 2>/dev/null)" == "library" ]] && continue
  yq -e '.dependencies[]? | select(.name == "platform-common")' "$chart/Chart.yaml" >/dev/null 2>&1 || continue
  helm dependency update "$chart" >/dev/null
  for vals in "$chart"values*.yaml; do
    echo "### $(basename "$chart") :: $(basename "$vals")"
    helm template rel "$chart" -f "$chart/values.yaml" -f "$vals" --api-versions autoscaling/v2
  done
done
