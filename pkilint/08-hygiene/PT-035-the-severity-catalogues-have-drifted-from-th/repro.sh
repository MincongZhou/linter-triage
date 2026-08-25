#!/bin/bash
# This one needs Python; the analysis is in repro.py.
exec python3 "$(dirname "$0")/repro.py" "$@"
