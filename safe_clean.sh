#!/bin/bash
# safe_clean.sh — Safely empty node_modules and Python venvs
# Usage: ./safe_clean.sh [--dry-run] [SEARCH_PATH]
# Default SEARCH_PATH: current dir

set -euo pipefail
IFS=$'\n'

# ─── Args ────────────────────────────────────────────────────────────────────
DRY_RUN=false
SEARCH_PATH="${2:-${1:-$PWD}}"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  SEARCH_PATH="${2:-$PWD}"
fi

echo "==> Search path : $SEARCH_PATH"
echo "==> Dry run     : $DRY_RUN"
echo ""

# ─── Helpers ─────────────────────────────────────────────────────────────────
bytes_freed=0
dry_run_total=0
node_count=0
venv_count=0
declare -A node_proj_sizes
declare -A venv_sizes

du_bytes() {
  du -sb "$1" 2>/dev/null | awk '{print $1}' || echo 0
}

human() {
  numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

has_node_lockfile() {
  local dir="$1"
  [[ -f "$dir/package.json" ]] || \
  [[ -f "$dir/pnpm-lock.yaml" ]] || \
  [[ -f "$dir/package-lock.json" ]] || \
  [[ -f "$dir/yarn.lock" ]]
}

has_python_lockfile() {
  local dir="$1"
  [[ -f "$dir/pyproject.toml" ]] || \
  [[ -f "$dir/poetry.lock" ]] || \
  [[ -f "$dir/uv.lock" ]] || \
  ls "$dir"/requirements*.txt >/dev/null 2>&1
}

# ─── Node: node_modules ──────────────────────────────────────────────────────
echo "── Node.js node_modules ─────────────────────────────────────────────────"

while IFS= read -r dir; do
  [[ "$dir" == *"/node_modules/"*"/node_modules" ]] && continue
  [[ -z "$(ls -A "$dir" 2>/dev/null)" ]] && continue

  proj_dir=$(dirname "$dir")

  if has_node_lockfile "$proj_dir"; then
    size=$(du_bytes "$dir")
    top_proj=$(echo "$proj_dir" | sed "s|$HOME/||" | cut -d'/' -f1-2)
    node_proj_sizes["$top_proj"]=$(( ${node_proj_sizes["$top_proj"]:-0} + size ))
    node_count=$((node_count + 1))

    if $DRY_RUN; then
      dry_run_total=$((dry_run_total + size))
      echo "    [dry-run] would empty $dir ($(human "$size"))"
    else
      rm -rf "${dir:?}"/*
      bytes_freed=$((bytes_freed + size))
      echo "    Emptied  $dir ($(human "$size") freed)"
    fi
  else
    echo "    SKIP  $dir (no package.json / lockfile in $proj_dir)"
  fi
done < <(find "$SEARCH_PATH" \
  -type d -name "node_modules" \
  ! -path "*/node_modules/*/node_modules" \
  ! -path "$HOME/.cursor/*" \
  ! -path "$HOME/.windsurf/*" \
  ! -path "$HOME/.vscode/*" \
  ! -path "$HOME/.npm/_npx/*" \
  ! -path "$HOME/.bun/*" \
  ! -path "$HOME/.local/share/pnpm/*" \
  ! -path "$HOME/.cache/*" \
  ! -path "$HOME/.gradle/*" \
  ! -path "$HOME/.nvm/*" \
  2>/dev/null)

# ─── Python: .venv / venv / env ──────────────────────────────────────────────
echo ""
echo "── Python venvs ─────────────────────────────────────────────────────────"

while IFS= read -r dir; do
  [[ ! -f "$dir/pyvenv.cfg" ]] && { echo "    SKIP  $dir (no pyvenv.cfg, not a real venv)"; continue; }

  proj_dir=$(dirname "$dir")

  if has_python_lockfile "$proj_dir"; then
    size=$(du_bytes "$dir")
    venv_sizes["$dir"]=$size
    venv_count=$((venv_count + 1))

    if $DRY_RUN; then
      dry_run_total=$((dry_run_total + size))
      echo "    [dry-run] would empty lib/include in $dir ($(human "$size"))"
    else
      size_before=$(du_bytes "$dir")
      rm -rf "${dir:?}"/lib/python*/site-packages/* 2>/dev/null || true
      rm -rf "${dir:?}"/include/* 2>/dev/null || true
      bytes_freed=$((bytes_freed + size_before))
      echo "    Emptied  $dir ($(human "$size_before") freed)"
    fi
  else
    echo "    SKIP  $dir (no pyproject.toml/requirements/uv.lock in $proj_dir)"
  fi
done < <(find "$SEARCH_PATH" \
  -type d \( -name ".venv" -o -name "venv" -o -name "env" \) \
  ! -path "*/.venv/*/venv" \
  ! -path "$HOME/.cursor/*" \
  ! -path "$HOME/.windsurf/*" \
  ! -path "$HOME/.cache/*" \
  ! -path "$HOME/.local/lib/*" \
  ! -path "$HOME/.rustup/*" \
  2>/dev/null)

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════════════"
$DRY_RUN && echo "  DRY-RUN SUMMARY" || echo "  CLEANUP SUMMARY"
echo "══════════════════════════════════════════════════════════════════════════"
echo ""
printf "  %-28s %5s dirs\n" "node_modules" "$node_count"
printf "  %-28s %5s envs\n" "Python venvs"  "$venv_count"
echo ""

if $DRY_RUN; then
  echo "  Total that WOULD be freed : $(human "$dry_run_total")"
  echo ""
  echo "  Top node_modules by project:"
  for proj in "${!node_proj_sizes[@]}"; do
    echo "    ${node_proj_sizes[$proj]} $proj"
  done | sort -rn | head -10 | while read sz proj; do
    printf "    %10s  %s\n" "$(human "$sz")" "$proj"
  done
  echo ""
  echo "  Top Python venvs:"
  for path in "${!venv_sizes[@]}"; do
    echo "    ${venv_sizes[$path]} $path"
  done | sort -rn | head -10 | while read sz path; do
    printf "    %10s  %s\n" "$(human "$sz")" "$path"
  done
  echo ""
  echo "  ➜  Run without --dry-run to apply."
else
  echo "  Total freed               : $(human "$bytes_freed")"
  echo "  Rebuild node : pnpm install  (per project)"
  echo "  Rebuild py   : uv sync       (per project)"
fi
echo "══════════════════════════════════════════════════════════════════════════"
