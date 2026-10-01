# Deploy — whiskeytangologistics.com

Push to `main`. That is the deploy.

The Cloudflare token already lives on `whiskytango25/wti-console` as
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. A workflow there
checks this repo out and runs `build.sh` then `scripts/publish.sh`.
It publishes only the Pages project that already has this domain, so a
push cannot create a second project or drop the custom domain.

`build.sh` copies the public files into `dist/`. Do not upload a folder
by hand. The last hand upload left out `index.html`, and the homepage 404ed.

First contact-form send still has to be confirmed by FormSubmit at
info@whiskeytangologistics.com. That is once, not a deploy step.
