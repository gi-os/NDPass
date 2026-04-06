# NDPass Server

Backend service for NDPass. Runs on BasilNet via Docker.

**Two jobs:**
1. **`POST /parse`** — Proxies ticket images to Claude Vision so the API key stays off your phone
2. **`POST /pass`** — Generates signed `.pkpass` files for Apple Wallet

## Deploy to BasilNet

```bash
# SSH into BasilNet
ssh Giovanni@192.168.68.59

# Clone (or pull) the repo
cd ~/docker
git clone https://github.com/gi-os/NDPass.git ndpass
cd ndpass/server

# Create .env (already has your API key in the template)
# Just fill in APPLE_TEAM_ID once you have it

# Build and run
docker compose up -d --build

# Verify
curl http://localhost:3939/
# → {"service":"ndpass-server","status":"ok",...}
```

The server will be available at `http://192.168.68.59:3939` on your LAN.

## Optional: Expose via Cloudflare Tunnel

If you want the app to work outside your home network (and you should), add it to your existing Cloudflare tunnel:

```bash
# Add to your cloudflared config (~/.cloudflared/config.yml)
# Under ingress, add:
#   - hostname: ndpass.yourdomain.com
#     service: http://localhost:3939
# Then restart cloudflared
```

## Apple Wallet Cert Setup

This is the annoying part but you only do it once:

### 1. Create a Pass Type ID

- Go to https://developer.apple.com/account/resources/identifiers/list/passTypeId
- Click `+` → "Pass Type IDs"
- Description: `NDPass Movie Ticket`
- Identifier: `pass.com.gios.ndpass`
- Register it

### 2. Create a signing certificate

- Still in the Apple Developer portal → Certificates
- Click `+` → "Pass Type ID Certificate"
- Select your `pass.com.gios.ndpass` identifier
- Follow the CSR steps (Keychain Access → Certificate Assistant → Request a Certificate)
- Download the `.cer` file

### 3. Export to PEM

```bash
# Convert .cer to .pem
openssl x509 -inform DER -in pass.cer -out signerCert.pem

# Export private key from Keychain as .p12, then:
openssl pkcs12 -in Certificates.p12 -clcerts -nokeys -out signerCert.pem
openssl pkcs12 -in Certificates.p12 -nocerts -out signerKey.pem

# Download Apple WWDR cert (G4)
curl -o wwdr.pem https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
openssl x509 -inform DER -in AppleWWDRCAG4.cer -out wwdr.pem
```

### 4. Put certs on BasilNet

```bash
scp signerCert.pem signerKey.pem wwdr.pem Giovanni@192.168.68.59:~/docker/ndpass/server/certs/
```

### 5. Restart

```bash
ssh Giovanni@192.168.68.59
cd ~/docker/ndpass/server
docker compose restart
```

## Updating the app to use the server

Once the server is running, update `lib/ai.ts` in the app to point to the server instead of calling Anthropic directly:

```typescript
// Replace the direct Anthropic call with:
const SERVER_URL = 'http://192.168.68.59:3939';
// or if tunneled: 'https://ndpass.yourdomain.com'

const response = await fetch(`${SERVER_URL}/parse`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ image: base64, mediaType }),
});
```

This is better because:
- API key never touches the phone
- You can rate-limit / log requests on the server
- Easier to swap models or add caching later
