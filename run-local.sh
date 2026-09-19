#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
python3 -m http.server 8000 --bind 127.0.0.1
