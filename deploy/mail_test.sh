#!/bin/sh
# The mail setting travels from the release workflow to the server and is
# read there as it was written. Run from the repository's root:
#
#   sh deploy/mail_test.sh
#
# A server with no key makes one and publishes its public half; a setting
# sealed to that half opens into the environment file; one sealed to
# another server's key leaves the file as it was.
set -eu
here=$(pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

mkdir -p "$t/release/deploy" "$t/etc"
cp deploy/mail.sh "$t/release/deploy/"
export SHIRABE_MAIL_KEY="$t/etc/mail.key" SHIRABE_MAIL_ENV="$t/etc/mail.env"
(cd "$t/release" && sh deploy/mail.sh) > "$t/said" || fail "mail.sh with no key"
[ -f "$t/release/public/mail-key.pem" ] || fail "no public key is published"
grep -q "made the server's key" "$t/said" || fail "it did not say it made a key"
[ ! -f "$t/etc/mail.env" ] || fail "an environment file with no sealed setting"

GMAIL_ADDRESS="ana+shows@gmail.com" GMAIL_APP_PASSWORD="abcd efgh ijkl mnop" \
  sh deploy/seal_mail.sh "file://$t/release/public/mail-key.pem" \
  "$t/release/deploy/mail.enc" > /dev/null || fail "seal_mail.sh"
(cd "$t/release" && sh deploy/mail.sh) > /dev/null || fail "mail.sh with a sealed setting"
want="SENRO_MAIL='smtp://ana%2Bshows%40gmail.com:abcdefghijklmnop@smtp.gmail.com:587'"
[ "$(cat "$t/etc/mail.env")" = "$want" ] || fail "the setting reads $(cat "$t/etc/mail.env")"

# Turnstile's keys travel with it, in the same file.
GMAIL_ADDRESS="ana+shows@gmail.com" GMAIL_APP_PASSWORD="abcd efgh ijkl mnop" \
  TURNSTILE_SITE_KEY="0x4AAAAAAAsite" TURNSTILE_SECRET_KEY="0x4AAAAAAAsecret" \
  sh deploy/seal_mail.sh "file://$t/release/public/mail-key.pem" \
  "$t/release/deploy/mail.enc" > /dev/null || fail "seal_mail.sh with Turnstile"
(cd "$t/release" && sh deploy/mail.sh) > /dev/null || fail "mail.sh with Turnstile"
keyed="$want
TURNSTILE_SITE_KEY='0x4AAAAAAAsite'
TURNSTILE_SECRET_KEY='0x4AAAAAAAsecret'"
[ "$(cat "$t/etc/mail.env")" = "$keyed" ] || fail "with Turnstile it reads $(cat "$t/etc/mail.env")"

# Sealed to another server's key, the setting is reported and the old one kept.
mkdir -p "$t/other/deploy"
cp deploy/mail.sh "$t/other/deploy/"
(cd "$t/other" && SHIRABE_MAIL_KEY="$t/other.key" sh deploy/mail.sh) > /dev/null
GMAIL_ADDRESS="bo@gmail.com" GMAIL_APP_PASSWORD="zzzz" \
  sh deploy/seal_mail.sh "file://$t/other/public/mail-key.pem" \
  "$t/release/deploy/mail.enc" > /dev/null
(cd "$t/release" && sh deploy/mail.sh) > "$t/said" || fail "mail.sh with a foreign seal"
grep -q "sealed to another key" "$t/said" || fail "a foreign seal went unreported"
[ "$(cat "$t/etc/mail.env")" = "$keyed" ] || fail "a foreign seal changed the setting"

# Without the secrets, nothing is sealed.
rm -f "$t/release/deploy/mail.enc"
sh deploy/seal_mail.sh "file://$t/release/public/mail-key.pem" "$t/release/deploy/mail.enc" \
  > /dev/null || fail "seal_mail.sh without secrets"
[ ! -f "$t/release/deploy/mail.enc" ] || fail "sealed with no secrets"
cd "$here"
echo "ok: the mail setting reaches the server sealed"
