# Deploy — whiskeytangologistics.com

Do not upload a folder, and do not create a second Pages project. The last hand upload left out `index.html`, so https://whiskeytangologistics.com/ is a 404 while `/legal` still loads.

`main` already has the homepage (legal link + contact form). `bash build.sh` copies the public files into `dist/`.

## Why a push is not live yet

The Cloudflare token on `whiskytango25/wti-console` (`CLOUDFLARE_API_TOKEN`) is the account that publishes wtic2.com, jack-mercer.com, and taskforce154.com. That account has six Pages projects. None of them, and no zone this token can see, is `whiskeytangologistics.com`. The publisher stops there on purpose.

Do not replace `CLOUDFLARE_API_TOKEN`. wtic2.com deploys with it.

## One time, in the dashboard you already upload from

1. Workers & Pages → the project whose custom domain is `whiskeytangologistics.com`.
2. Settings → Builds & deployments → Connect to Git.
3. Repository: `whiskytango25/whiskeytangologistics-site`
4. Production branch: `main`
5. Build command: `bash build.sh`
6. Build output directory: `dist`

Save and let that build finish. The homepage should answer 200 and link to `/legal`. After that, a push to `main` is the deploy.

The contact form posts to FormSubmit. The first real send still has to be confirmed once at info@whiskeytangologistics.com.
