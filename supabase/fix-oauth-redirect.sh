#!/bin/bash
# Fix Supabase OAuth Redirect URI
# This script updates the Supabase configuration to use the correct external URL
# Run this on the server after deploying

set -e

SITE_URL="https://khetbata.xyz"
EXTERNAL_URL="https://khetbata.xyz/_supabase"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-976742567993-t2ckb1olg9tslhnc5c92qii8hu8fqen0.apps.googleusercontent.com}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-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}"

echo "=== Supabase OAuth Configuration Fix ==="
echo "SITE_URL: $SITE_URL"
echo "EXTERNAL_URL: $EXTERNAL_URL"
echo ""

# Find Supabase directory
SUPABASE_DIR=""
if [ -d ~/jirisewa/apps/web/supabase ]; then
    SUPABASE_DIR=~/jirisewa/apps/web/supabase
elif [ -d ~/jirisewa/supabase ]; then
    SUPABASE_DIR=~/jirisewa/supabase
elif [ -d ~/urja/web/supabase ]; then
    SUPABASE_DIR=~/urja/web/supabase
else
    echo "ERROR: Cannot find Supabase directory"
    exit 1
fi

echo "Found Supabase directory: $SUPABASE_DIR"
cd "$SUPABASE_DIR"

# Update config.toml
echo "Updating config.toml..."
cat > config.toml << 'CONFIGEOF'
project_id = "jirisewa"

[db]
port = 54322
major_version = 17

[db.pooler]
enabled = false
port = 54329
pool_mode = "transaction"

[studio]
enabled = true
port = 54323

[api]
enabled = true
port = 54321
schemas = ["public"]
external_url = "EXTERNAL_URL_PLACEHOLDER"

[auth]
enabled = true
site_url = "SITE_URL_PLACEHOLDER"
additional_redirect_urls = ["SITE_URL_PLACEHOLDER/_supabase/auth/v1/callback"]

[auth.sms]
enable_signup = true
enable_confirmations = false
template = "Your code is {{ .Code }}"
max_frequency = "0s"

[auth.email]
enable_signup = false
enable_confirmations = false

[auth.external.google]
enabled = true
client_id = "GOOGLE_CLIENT_ID_PLACEHOLDER"
secret = "GOOGLE_CLIENT_SECRET_PLACEHOLDER"

[auth.sms.test_otp]
9779800000001 = "123456"
9779800000002 = "123456"
9779800000003 = "123456"
9779800000004 = "123456"

[storage]
enabled = true

[realtime]
enabled = true
CONFIGEOF

# Replace placeholders
sed -i "s|EXTERNAL_URL_PLACEHOLDER|$EXTERNAL_URL|g" config.toml
sed -i "s|SITE_URL_PLACEHOLDER|$SITE_URL|g" config.toml
sed -i "s|GOOGLE_CLIENT_ID_PLACEHOLDER|$GOOGLE_CLIENT_ID|g" config.toml
sed -i "s|GOOGLE_CLIENT_SECRET_PLACEHOLDER|$GOOGLE_CLIENT_SECRET|g" config.toml

echo "Config updated. Restarting Supabase..."
supabase stop

# Start with environment variable
GOTRUE_EXTERNAL_URL="$EXTERNAL_URL" supabase start

echo ""
echo "=== Verifying configuration ==="
sleep 5

# Test the authorize endpoint
AUTHORIZE_URL="https://khetbata.xyz/_supabase/auth/v1/authorize?provider=google"
REDIRECT_URI=$(curl -s "$AUTHORIZE_URL" | grep -o 'redirect_uri=[^&]*' | sed 's/&amp;/\&/g' | cut -d'=' -f2)

if [[ "$REDIRECT_URI" == *"127.0.0.1"* ]] || [[ "$REDIRECT_URI" == *"localhost"* ]]; then
    echo "WARNING: redirect_uri still uses localhost: $REDIRECT_URI"
    echo "The OAuth callback will not work from external clients."
    echo ""
    echo "You may need to set GOTRUE_EXTERNAL_URL environment variable:"
    echo "  export GOTRUE_EXTERNAL_URL=$EXTERNAL_URL"
    echo "  supabase restart"
else
    echo "SUCCESS: redirect_uri configured correctly: $REDIRECT_URI"
fi

