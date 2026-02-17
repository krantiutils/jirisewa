# JiriSewa Deployment Guide

## Server Information
- **Server**: ubuntu@54.156.88.160
- **Domain**: https://khetbata.xyz
- **Project path**: ~/jirisewa/apps/web

## Quick Deploy

```bash
# 1. SSH into the server
ssh ubuntu@54.156.88.160

# 2. Navigate to project
cd ~/jirisewa/apps/web

# 3. Pull latest changes
git pull origin master

# 4. Install dependencies (if needed)
npm install

# 5. Build the app
npm run build

# 6. Restart the service
pm2 restart jirisewa-frontend

# 7. Check logs
pm2 logs jirisewa-frontend --lines 50
```

## Supabase OAuth Configuration

For Google OAuth to work correctly, the Supabase instance needs to know its external URL.

### Method 1: Run the fix script (Recommended)

```bash
cd ~/jirisewa/apps/web/supabase
bash fix-oauth-redirect.sh
```

### Method 2: Manual configuration

1. Update `~/jirisewa/apps/web/supabase/config.toml`:
```toml
[api]
external_url = "https://khetbata.xyz/_supabase"

[auth]
site_url = "https://khetbata.xyz"
additional_redirect_urls = ["https://khetbata.xyz/_supabase/auth/v1/callback"]
```

2. Set environment variable and restart Supabase:
```bash
export GOTRUE_EXTERNAL_URL="https://khetbata.xyz/_supabase"
cd ~/jirisewa/apps/web/supabase
supabase stop
supabase start
```

3. Verify the configuration:
```bash
curl -s "https://khetbata.xyz/_supabase/auth/v1/authorize?provider=google" | grep -o 'redirect_uri=[^&]*'
# Should show: https://khetbata.xyz/_supabase/auth/v1/callback
# NOT: http://127.0.0.1:54321/auth/v1/callback
```

## Google Cloud Console Configuration

Make sure the following redirect URI is added to your Google OAuth 2.0 Client:

```
https://khetbata.xyz/_supabase/auth/v1/callback
```

Go to: https://console.cloud.google.com/apis/credentials
Select your OAuth 2.0 Client ID
Add the URI to "Authorized redirect URIs"

## Environment Variables

The following environment variables should be set in `.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://khetbata.xyz/_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key>
NEXT_PUBLIC_BASE_URL=https://khetbata.xyz
NEXT_PUBLIC_GOOGLE_CLIENT_ID=976742567993-t2ckb1olg9tslhnc5c92qii8hu8fqen0.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=<your-secret>
```

## Nginx Configuration

The nginx config at `/etc/nginx/sites-available/khetbata` should have these location blocks:

```nginx
# Supabase Auth callback
location /_supabase/auth/v1/callback {
    proxy_pass http://127.0.0.1:54321/auth/v1/callback;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# Supabase Auth API
location /_supabase/auth/v1/ {
    proxy_pass http://127.0.0.1:54321/auth/v1/;
    # ... same proxy headers
}

# Supabase REST API
location /_supabase/rest/v1/ {
    proxy_pass http://127.0.0.1:54321/rest/v1/;
    # ... same proxy headers
}

# Supabase Storage
location /_supabase/storage/v1/ {
    proxy_pass http://127.0.0.1:54321/storage/v1/;
    # ... same proxy headers
}
```

After changing nginx config:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Testing

1. **Site is up**: `curl -s -o /dev/null -w '%{http_code}' https://khetbata.xyz`
2. **Supabase API**: `curl -s https://khetbata.xyz/_supabase/rest/v1/ | head -5`
3. **OAuth endpoint**: Check redirect URI as shown above

## Troubleshooting

### OAuth redirect URI shows localhost
This means GOTRUE_EXTERNAL_URL is not set. Run the fix script or set the environment variable.

### Build fails with ENOENT error
```bash
rm -rf .next
npm run build
```

### Supabase not accessible
```bash
# Check if Supabase is running
ps aux | grep supabase

# Restart Supabase
cd ~/jirisewa/apps/web/supabase
supabase stop
supabase start
```
