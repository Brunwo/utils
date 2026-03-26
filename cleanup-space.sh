

#!/bin/bash
pnpm store prune

rm -rf ~/.local/share/pnpm/store


# Removes old revisions of snaps
# CLOSE ALL SNAPS BEFORE RUNNING THIS

#pkill -f blender, firefox --quit).


set -eu

LANG=C snap list --all | awk '/disabled/{print $1, $3}' | \
  while read snapname revision; do
    echo ">>> Removing $snapname (rev $revision)..."
    if timeout 30 sudo snap remove --purge "$snapname" --revision="$revision"; then
      echo "    ✓ Done: $snapname rev $revision"
    else
      echo "    ✗ FAILED or TIMED OUT: $snapname rev $revision — skipping"
    fi
  done

LANG=C snap list --all | awk '/disabled/{print $1, $3}' | \
  while read snapname revision; do
    sudo snap remove "$snapname" --revision="$revision"
  done


#Reduce Future Storage Usage   
sudo snap set system refresh.retain=2



#UV cache purge

uv cache prune  # Prunes unused archives/environments
uv cache clean #stronger option

#virt envs / node_modules purge
#with declarative depts file present (requirements*.txt ...)



#other possibilities : 

# - ace (often 100MB-1GB each)

# __pnpm:__

# - No `.pnpm-store` found in `/home/bruno/`
# - pnpm typically stores packages in `~/.pnpm-store` or `~/.local/share/pnpm/store`

# __Other storage locations:__

# - Global npm packages: `~/.npm`
# - Yarn cache: `~/.yarn`
# - pnpm global store: `~/.local/share/pnpm/store`

# To clean up, you can:

# 1. Remove unused node_modules directories
# 2. Clear npm cache: `npm cache clean --force`
# 3. Clear pnpm store if it exists
# 4. Remove global packages you don't use

