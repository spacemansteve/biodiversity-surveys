#!/usr/bin/env bash

# Source from Bash before working in an application repository:
#   source ./env.sh
export BIODIVERSITY_SURVEYS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Compatibility alias for existing local tooling.
export SWIFTY_ROOT="$BIODIVERSITY_SURVEYS_ROOT"
export RBENV_ROOT="${RBENV_ROOT:-$BIODIVERSITY_SURVEYS_ROOT/.toolchains/rbenv}"
if [ -d "$BIODIVERSITY_SURVEYS_ROOT/.docker" ]; then
  export DOCKER_CONFIG="${DOCKER_CONFIG:-$BIODIVERSITY_SURVEYS_ROOT/.docker}"
fi
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib${LDFLAGS:+ $LDFLAGS}"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include${CPPFLAGS:+ $CPPFLAGS}"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libpq/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH="$RBENV_ROOT/bin:$BIODIVERSITY_SURVEYS_ROOT/.toolchains/node-24.15.0/bin:/opt/homebrew/opt/libpq/bin:/opt/homebrew/bin:$PATH"

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - bash)"
fi
