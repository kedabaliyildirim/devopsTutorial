#!/usr/bin/env bash
set -euo pipefail

echo "== Interfaces =="
ip addr

echo "== Routes =="
ip route

echo "== Listening ports (first 20) =="
ss -tulpn | head -20
