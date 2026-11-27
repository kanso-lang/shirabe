#!/bin/sh
# Run by the release workflow: seals the mail setting to the server's public
# key, read from <key-url>, and writes it to <out> for deploy/mail.sh to
# open on the server. Cloudflare Turnstile's two keys travel with it when
# both are set, and the sign-up and reset forms then ask Turnstile.
#
#   GMAIL_ADDRESS=... GMAIL_APP_PASSWORD=... \
#     TURNSTILE_SITE_KEY=... TURNSTILE_SECRET_KEY=... \
#     sh deploy/seal_mail.sh <key-url> <out>
#
# The app sends through Gmail with an app password, which Google shows in
# groups of four letters; the spaces are dropped. Without both secrets, or
# before the server has published its key, the release carries no setting
# and the server keeps the one it has.
set -eu
url=$1
out=$2
if [ -z "${GMAIL_ADDRESS:-}" ] || [ -z "${GMAIL_APP_PASSWORD:-}" ]; then
  echo "seal_mail: no GMAIL_ADDRESS and GMAIL_APP_PASSWORD secrets; no mail setting"
  exit 0
fi
pw=$(printf %s "$GMAIL_APP_PASSWORD" | tr -d ' ')
[ -z "${GITHUB_ACTIONS:-}" ] || echo "::add-mask::$pw"
name=$(printf %s "$GMAIL_ADDRESS" | sed 's/%/%25/g; s/+/%2B/g; s/@/%40/g')
key=$(mktemp)
trap 'rm -f "$key"' EXIT
if ! curl -sf "$url" -o "$key"; then
  echo "seal_mail: the server publishes no key at $url yet; no mail setting"
  exit 0
fi
setting=$(printf "SENRO_MAIL='smtp://%s:%s@smtp.gmail.com:587'" "$name" "$pw")
if [ -n "${TURNSTILE_SITE_KEY:-}" ] && [ -n "${TURNSTILE_SECRET_KEY:-}" ]; then
  [ -z "${GITHUB_ACTIONS:-}" ] || echo "::add-mask::$TURNSTILE_SECRET_KEY"
  setting="$setting
TURNSTILE_SITE_KEY='$TURNSTILE_SITE_KEY'
TURNSTILE_SECRET_KEY='$TURNSTILE_SECRET_KEY'"
  echo "seal_mail: Turnstile's keys go with it"
fi
printf '%s\n' "$setting" |
  openssl pkeyutl -encrypt -pubin -inkey "$key" \
    -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -out "$out"
echo "seal_mail: sealed the mail setting to the server's key"
