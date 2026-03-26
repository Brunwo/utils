

#!/bin/bash
pnpm store prune

rm -rf ~/.local/share/pnpm/store


# Removes old revisions of snaps
# CLOSE ALL SNAPS BEFORE RUNNING THIS

#pkill -f blender, firefox --quit).


set -eu

LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
    while read snapname revision; do
        snap remove "$snapname" --revision="$revision"
    done
    

#Reduce Future Storage Usage   
sudo snap set system refresh.retain=2



#UV cache purge

uv cache prune  # Prunes unused archives/environments
uv cache clean #stronger option

#virt envs / node_modules purge
#with declarative depts file present (requirements*.txt ...)
