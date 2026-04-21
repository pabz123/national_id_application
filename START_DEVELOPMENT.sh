#!/bin/bash

# National ID Application - Development Environment Setup Script
# This script starts both Odoo and Flutter services for local development
# Usage: bash START_DEVELOPMENT.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_ROOT="$(cd "$PROJECT_ROOT/../.." && pwd)"
FLUTTER_APP="$PROJECT_ROOT/flutter_app"

echo "════════════════════════════════════════════════════════════════"
echo "  National ID Application - Development Setup"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Step 1: Install Odoo dependencies
echo "📦 Installing Odoo dependencies..."
cd "$ODOO_ROOT"
if [ ! -d "$ODOO_ROOT/venv" ]; then
  echo "   ⚠️  No virtual environment found at $ODOO_ROOT/venv"
  echo "   Please run: python3 -m venv venv (in $ODOO_ROOT)"
  exit 1
fi

source "$ODOO_ROOT/venv/bin/activate"
pip install -q passlib psycopg2-binary 2>/dev/null || true
echo "   ✅ Dependencies installed"
echo ""

# Step 2: Start Odoo
echo "🚀 Starting Odoo (port 8067)..."
cd "$ODOO_ROOT"
source "$ODOO_ROOT/venv/bin/activate"
"$ODOO_ROOT/venv/bin/python" odoo-bin -d Odoo-Project \
  --addons-path=addons,custom_addons \
  --http-port=8067 \
  --logfile=/tmp/odoo.log \
  2>/dev/null &

ODOO_PID=$!
echo "   Odoo PID: $ODOO_PID"

# Wait for Odoo to start
echo "   ⏳ Waiting for Odoo to initialize (20 seconds)..."
sleep 20

# Test Odoo API
if curl -s --max-time 3 'http://127.0.0.1:8067/api/mobile/metadata?db=Odoo-Project' > /dev/null 2>&1; then
  echo "   ✅ Odoo API is responding"
else
  echo "   ❌ Odoo API is not responding. Check: tail -f /tmp/odoo.log"
  kill $ODOO_PID 2>/dev/null || true
  exit 1
fi
echo ""

# Step 3: Build and Start Flutter
echo "🚀 Building and Starting Flutter Web (port 5000)..."
cd "$FLUTTER_APP"

# Clean and build if not already built
if [ ! -f "$FLUTTER_APP/build/web/flutter_bootstrap.js" ]; then
  echo "   ⏳ Building Flutter web app (this may take 2-3 minutes)..."
  /home/precious/flutter/bin/flutter build web --release 2>/dev/null || true
fi

# Start HTTP server to serve built app
cd "$FLUTTER_APP/build/web"
python3 -m http.server 5000 > /tmp/flutter.log 2>&1 &

FLUTTER_PID=$!
echo "   Flutter Server PID: $FLUTTER_PID"

# Wait for Flutter server to start
echo "   ⏳ Waiting for Flutter Web to initialize (5 seconds)..."
sleep 5

# Test Flutter Web
if curl -s --max-time 3 'http://127.0.0.1:5000' > /dev/null 2>&1; then
  echo "   ✅ Flutter Web is responding"
else
  echo "   ❌ Flutter Web is not responding. Check: tail -f /tmp/flutter.log"
  kill $ODOO_PID $FLUTTER_PID 2>/dev/null || true
  exit 1
fi
echo ""

# Success!
echo "════════════════════════════════════════════════════════════════"
echo "✅ SERVICES STARTED SUCCESSFULLY!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📍 ENDPOINTS:"
echo "   • Odoo Backend:  http://127.0.0.1:8067"
echo "   • Flutter App:   http://127.0.0.1:5000"
echo ""
echo "📝 LOGS:"
echo "   • Odoo:   tail -f /tmp/odoo.log"
echo "   • Flutter: tail -f /tmp/flutter.log"
echo ""
echo "🛑 TO STOP:"
echo "   • Kill Odoo:  kill $ODOO_PID"
echo "   • Kill Flutter: kill $FLUTTER_PID"
echo "   • Or press Ctrl+C to stop"
echo ""
echo "Ready to test! Open http://127.0.0.1:5000 in your browser."
echo ""

# Keep script running
wait $ODOO_PID $FLUTTER_PID
