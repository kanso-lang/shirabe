# shirabe

shirabe (調べ, "melody") is a music app built with [senro](https://github.com/kanso-lang/senro),
the web framework for [kanso](https://github.com/kanso-lang/kanso). It keeps
artists, their albums, and each album's tracks, with an audio file for each
track. It is also senro's first app outside senro's own repository, so what
it needs and senro lacks becomes senro's next change.

## Running it

The app needs kanso, senro's command on the PATH, and a Postgres it can
reach through the usual `PG*` variables:

```
kanso install .
senro test
senro server
```

`kanso install` fetches the senro release `hako.lock` pins. The app runs its
migrations as it starts.

## How it is deployed

A push to `main` runs CI, which builds kanso at the commit `.kanso-version`
pins, runs the tests, builds the release binary, and publishes it as a
GitHub release. The server asks for the latest release once a minute, checks
the download against its sha256, and restarts the app on it. Nothing logs in
to deploy.

The server is set up on its first boot by `deploy/cloud-init.yml`: Postgres,
Caddy in front of the app with a certificate for the server's `sslip.io`
name, and the timer that pulls releases. The database password and the
session secret are made there, at random, and never leave the server.

The app sends its mail through Gmail. The address and an app password are
the repository's `GMAIL_ADDRESS` and `GMAIL_APP_PASSWORD` Actions secrets.
The server makes a key pair on its first start and serves the public half
at `/mail-key.pem`. CI encrypts the mail setting to that key and puts it in
the release, and `deploy/mail.sh` decrypts it on the server before the app
starts, so the password is readable only there. After changing a secret,
run the `ci` workflow on `main` by hand to publish a release that carries
it. `deploy/mail_test.sh` checks the whole trip.

Sign-up and the password-reset form ask Cloudflare Turnstile whether a
person sent them, once the repository has the widget's two keys as the
`TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY` Actions secrets. They travel
to the server sealed with the mail setting. Without them the forms still
turn away a program that fills their hidden field, and each lets one
address in ten times an hour and everyone together a hundred times a day.

Hetzner has no spending cap, so the `cost` workflow is one. Every day it
prices everything in the Hetzner project at Hetzner's own rates: servers
and their backups, traffic past what a server includes (projected to the
month's end), IPs, volumes, load balancers and snapshots. The run fails,
and GitHub mails the failure, when the month would cost more than
`deploy/cost/budget` euros. It reads the project with
`HCLOUD_READ_TOKEN`, a read-only token, so it can only look. Object
storage is outside Hetzner's Cloud API, so a bucket is not counted.
