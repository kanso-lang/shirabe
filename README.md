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
to deploy, and the repository holds no secrets.

The server is set up on its first boot by `deploy/cloud-init.yml`: Postgres,
Caddy in front of the app with a certificate for the server's `sslip.io`
name, and the timer that pulls releases. The database password and the
session secret are made there, at random, and never leave the server.
