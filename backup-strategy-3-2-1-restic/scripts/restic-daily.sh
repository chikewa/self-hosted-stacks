#!/usr/bin/env bash
set -euo pipefail
REPO=/mnt/backup-disk/init
PASS=~/.config/restic/pass
PATHS=$(cat ~/.config/restic/paths.txt | tr '\n' ' ')

restic -r "$REPO" --password-file "$PASS" backup $PATHS --tag daily
restic -r "$REPO" --password-file "$PASS" forget --tag daily --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune

# Spot-check: verify a sample of files (full verify is the weekly job)
if ! restic -r "$REPO" --password-file "$PASS" check --read-data-subset=0.01; then
  echo "restic check failed" | mail -s "BACKUP PROBLEM on $(hostname)" you@example.com
fi
