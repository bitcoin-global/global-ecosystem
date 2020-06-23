#!/bin/sh
set -e

if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for bitglobd"

  set -- bitglobd "$@"
fi

if [ $(echo "$1" | cut -c1) = "-" ] || [ "$1" = "bitglobd" ]; then
  mkdir -p "$BITGLOB_DATA"
  chmod 700 "$BITGLOB_DATA"
  chown -R bitglob "$BITGLOB_DATA"

  echo "$0: setting data directory to $BITGLOB_DATA"

  set -- "$@" -datadir="$BITGLOB_DATA"
fi

if [ "$1" = "bitglobd" ] || [ "$1" = "bitglob-cli" ] || [ "$1" = "bitglob-tx" ]; then
  echo
  exec gosu bitglob "$@"
fi

echo
exec "$@"