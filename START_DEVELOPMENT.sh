#!/bin/bash
# ============================================================================
#  START_DEVELOPMENT.sh  –  National ID Application
#  its meant to work on ANY machine after cloning / on a fresh Odoo database.
#
#  Usage:
#    bash START_DEVELOPMENT.sh [--db <db-name>] [--odoo-port <port>]
#                              [--flutter-port <port>] [--install]
#
#  Flags:
#    --db <name>          Odoo database name  (default: Odoo-Project)
#    --odoo-port <port>   Odoo HTTP port      (default: 8067)
#    --flutter-port <p>   Flutter web port    (default: 5000)
#    --install            (Re-)install the Odoo module before starting
#    --init-db            Create a fresh database, then install module
# ============================================================================
set -euo pipefail

# ── Default configuration ────────────────────────────────────────────────────
DB_NAME="Odoo-Project"
ODOO_PORT="8067"
FLUTTER_PORT="5000"
DO_INSTALL=false
INIT_DB=false

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)          DB_NAME="$2";      shift 2 ;;
    --odoo-port)   ODOO_PORT="$2";    shift 2 ;;
    --flutter-port) FLUTTER_PORT="$2"; shift 2 ;;
    --install)     DO_INSTALL=true;   shift ;;
    --init-db)     INIT_DB=true; DO_INSTALL=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Resolve paths ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Support two layouts:
#   A) Script lives inside the module:  .../national_id_application/
#   B) Script lives one level up:       .../custom_addons/
# We need ODOO_ROOT (where odoo-bin lives) and ADDONS_DIR.

# Walk up until we find odoo-bin
find_odoo_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/odoo-bin" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

ODOO_ROOT=""
ODOO_ROOT="$(find_odoo_root "$SCRIPT_DIR")" || true

if [[ -z "$ODOO_ROOT" ]]; then
  # Try common locations relative to script
  for candidate in \
      "$SCRIPT_DIR/../../.." \
      "$SCRIPT_DIR/../../../.." \
      "$HOME/odoo" \
      "$HOME/odoo-19" \
      "/opt/odoo"; do
    candidate="$(realpath "$candidate" 2>/dev/null || true)"
    if [[ -f "$candidate/odoo-bin" ]]; then
      ODOO_ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "$ODOO_ROOT" ]]; then
  echo "❌  Cannot find odoo-bin. Set ODOO_ROOT manually or run this script"
  echo "   from inside your Odoo source tree."
  exit 1
fi

# Find the flutter_app directory
FLUTTER_APP=""
for candidate in \
    "$SCRIPT_DIR/flutter_app" \
    "$SCRIPT_DIR/../flutter_app" \
    "$(find "$SCRIPT_DIR" -maxdepth 3 -name "pubspec.yaml" -exec dirname {} \; 2>/dev/null | head -1)"; do
  if [[ -f "$candidate/pubspec.yaml" ]]; then
    FLUTTER_APP="$(realpath "$candidate")"
    break
  fi
done

if [[ -z "$FLUTTER_APP" ]]; then
  echo "❌  Cannot find flutter_app (pubspec.yaml). Expected at $SCRIPT_DIR/flutter_app"
  exit 1
fi

# Find the custom addons directory (parent of the module folder that contains __manifest__.py)
MODULE_DIR="$(find "$SCRIPT_DIR" -maxdepth 2 -name "__manifest__.py" -exec dirname {} \; 2>/dev/null | head -1)"
if [[ -z "$MODULE_DIR" ]]; then
  echo "❌  Cannot find __manifest__.py in or near $SCRIPT_DIR"
  exit 1
fi
ADDONS_DIR="$(dirname "$MODULE_DIR")"

# ── Find Python / venv ───────────────────────────────────────────────────────
PYTHON=""
for candidate in \
    "$ODOO_ROOT/venv/bin/python" \
    "$ODOO_ROOT/.venv/bin/python" \
    "$(command -v python3 2>/dev/null)"; do
  if [[ -x "$candidate" ]]; then
    PYTHON="$candidate"
    break
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "❌  No Python found. Install Python 3 or create a virtualenv at $ODOO_ROOT/venv"
  exit 1
fi

# ── Find Flutter ─────────────────────────────────────────────────────────────
FLUTTER_BIN=""
for candidate in \
    "$(command -v flutter 2>/dev/null)" \
    "$HOME/flutter/bin/flutter" \
    "$HOME/snap/flutter/current/bin/flutter" \
    "/usr/local/flutter/bin/flutter"; do
  if [[ -x "$candidate" ]]; then
    FLUTTER_BIN="$candidate"
    break
  fi
done

if [[ -z "$FLUTTER_BIN" ]]; then
  echo "❌  Flutter not found. Install Flutter and ensure it is on your PATH."
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  National ID Application – Development Environment"
echo "════════════════════════════════════════════════════════════"
echo "  Odoo root  : $ODOO_ROOT"
echo "  Module dir : $MODULE_DIR"
echo "  Addons dir : $ADDONS_DIR"
echo "  Flutter app: $FLUTTER_APP"
echo "  Database   : $DB_NAME"
echo "  Odoo port  : $ODOO_PORT"
echo "  Flutter port: $FLUTTER_PORT"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Install Python dependencies ───────────────────────────────────────────────
echo " Installing Python dependencies…"
"$PYTHON" -m pip install -q passlib psycopg2-binary python-dateutil 2>/dev/null || true
echo "    ✅ Python deps ready"

# ── Optionally create the database ───────────────────────────────────────────
if $INIT_DB; then
  echo ""
  echo "   Creating database '$DB_NAME'…"
  createdb "$DB_NAME" 2>/dev/null || echo "    (database may already exist – continuing)"
  echo "    ✅ Database ready"
fi

# ── Optionally install / upgrade the module ──────────────────────────────────
if $DO_INSTALL; then
  echo ""
  echo "🔧  Installing/upgrading national_id_application module…"
  "$PYTHON" "$ODOO_ROOT/odoo-bin" \
    -d "$DB_NAME" \
    --addons-path="$ODOO_ROOT/addons,$ADDONS_DIR" \
    -i national_id_application \
    --stop-after-init \
    --without-demo=all \
    --logfile=/tmp/odoo_install.log \
    2>/dev/null
  echo "    ✅ Module installed (log: /tmp/odoo_install.log)"
fi

# ── Start Odoo ────────────────────────────────────────────────────────────────
echo ""
echo "  Starting Odoo on port $ODOO_PORT…"
"$PYTHON" "$ODOO_ROOT/odoo-bin" \
  -d "$DB_NAME" \
  --addons-path="$ODOO_ROOT/addons,$ADDONS_DIR" \
  --http-port="$ODOO_PORT" \
  --logfile=/tmp/odoo.log \
  2>/dev/null &
ODOO_PID=$!

echo "    Odoo PID: $ODOO_PID"
echo "    ⏳ Waiting for Odoo to start…"

# Poll until API responds (up to 40 s)
for i in $(seq 1 40); do
  if curl -sf --max-time 2 \
      "http://127.0.0.1:$ODOO_PORT/api/mobile/metadata?db=$DB_NAME" \
      > /dev/null 2>&1; then
    echo "    ✅ Odoo API is responding"
    break
  fi
  sleep 1
  if [[ $i -eq 40 ]]; then
    echo "    ❌ Odoo did not respond after 40 s. Check: tail -f /tmp/odoo.log"
    kill "$ODOO_PID" 2>/dev/null || true
    exit 1
  fi
done

# ── Flutter pub get ───────────────────────────────────────────────────────────
echo ""
echo " Running flutter pub get…"
cd "$FLUTTER_APP"
"$FLUTTER_BIN" pub get --suppress-analytics 2>/dev/null
echo "    ✅ Packages ready"

# ── Build Flutter web if needed ───────────────────────────────────────────────
if [[ ! -f "$FLUTTER_APP/build/web/flutter_bootstrap.js" ]]; then
  echo ""
  echo "🔨  Building Flutter web (first run – takes ~2-3 min)…"
  "$FLUTTER_BIN" build web --release \
    --dart-define=API_BASE_URL="http://127.0.0.1:$ODOO_PORT" \
    --suppress-analytics 2>/dev/null
  echo "    ✅ Flutter web built"
fi

# ── Serve Flutter web ─────────────────────────────────────────────────────────
echo ""
echo " Serving Flutter web on port $FLUTTER_PORT…"
cd "$FLUTTER_APP/build/web"
"$PYTHON" -m http.server "$FLUTTER_PORT" > /tmp/flutter.log 2>&1 &
FLUTTER_PID=$!

sleep 3
if curl -sf --max-time 3 "http://127.0.0.1:$FLUTTER_PORT" > /dev/null 2>&1; then
  echo "    ✅ Flutter web is responding"
else
  echo "    ❌ Flutter web not responding. Check: tail -f /tmp/flutter.log"
  kill "$ODOO_PID" "$FLUTTER_PID" 2>/dev/null || true
  exit 1
fi

# ── Success ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅  ALL SERVICES RUNNING"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  📍 Flutter app :  http://127.0.0.1:$FLUTTER_PORT"
echo "  📍 Odoo backend:  http://127.0.0.1:$ODOO_PORT"
echo ""
echo "  📝 Logs:"
echo "     Odoo   → tail -f /tmp/odoo.log"
echo "     Flutter→ tail -f /tmp/flutter.log"
echo ""
echo "  🛑 To stop everything:"
echo "     kill $ODOO_PID $FLUTTER_PID"
echo ""
echo "  💡 First time on a new machine? Run:"
echo "     bash START_DEVELOPMENT.sh --init-db --install"
echo ""
echo "  💡 After a code change to the Odoo module, run:"
echo "     bash START_DEVELOPMENT.sh --install"
echo ""
echo "  💡 To rebuild Flutter after code changes:"
echo "     cd $FLUTTER_APP"
echo "     flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:$ODOO_PORT"
echo ""

# Keep the script alive so both background processes run
wait "$ODOO_PID" "$FLUTTER_PID"
