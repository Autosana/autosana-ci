#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'AUTOSANA_CI_BRANCH_MARKER=branch-hook-ran' >> /tmp/autosana.env
