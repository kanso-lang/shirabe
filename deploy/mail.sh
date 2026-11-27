#!/bin/sh
# Run as root from the release directory before the app starts, by
# `ExecStartPre=+` in shirabe.service.
#
# The app sends mail the way SENRO_MAIL names, and that names a password, so
# it cannot travel in a public release as it is. The server keeps a key pair
# of its own. The private half stays in /etc/shirabe and the public half is
# served at /mail-key.pem. The release workflow encrypts SENRO_MAIL to that
# public half (deploy/seal_mail.sh), and this decrypts it into the
# environment file the service reads.
#
# A setting that does not decrypt, as one sealed to an earlier server's key
# would not, is reported and the app starts with the setting it had.
#
# The SHIRABE_MAIL_* variables are for deploy/mail_test.sh.
set -eu
key=${SHIRABE_MAIL_KEY:-/etc/shirabe/mail.key}
out=${SHIRABE_MAIL_ENV:-/etc/shirabe/mail.env}
oaep="-pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256"

if [ ! -f "$key" ]; then
  (umask 077 && openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
    -out "$key" 2>/dev/null)
  echo "shirabe mail: made the server's key"
fi
mkdir -p public
openssl pkey -in "$key" -pubout -out public/mail-key.pem

[ -f deploy/mail.enc ] || exit 0
# shellcheck disable=SC2086
if (umask 077 && openssl pkeyutl -decrypt -inkey "$key" $oaep \
  -in deploy/mail.enc -out "$out.new" 2>/dev/null); then
  mv "$out.new" "$out"
  echo "shirabe mail: the release's mail setting is in place"
else
  rm -f "$out.new"
  echo "shirabe mail: the release's mail setting was sealed to another key; keeping the old one"
fi
