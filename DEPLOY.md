# Deploy — whiskeytangologistics.com

This folder is the Cloudflare Pages project for the company site.

## What changed 2026-09-30

- Footer Legal now points at `/legal` on this host, not the Lemon Squeezy custom domain.
- `legal/index.html` is in the tree so `/legal` stops 404ing.
- `_redirects` sends `/legal.html` to `/legal`.

## Publish (pick one)

### A. Direct upload (fastest)

Cloudflare Dashboard → Pages → the project bound to `whiskeytangologistics.com` → Create deployment → Upload this whole folder (`index.html`, `legal/`, `_redirects`, `_headers`, `robots.txt`).

### B. Git (durable)

Repo: `whiskytango25/whiskeytangologistics-site`
Connect that repo to the existing Pages project, production branch `main`. Future edits ship on push.

Do not upload `site/landing/` alone again. That is how legal went missing.

## What changed 2026-10-01

- `/` was 404 in production because the last upload did not include `index.html`. Upload this whole folder, not `legal/` alone.
- Header on the home page links to `/legal`.
- Contact is a form (name, email, phone, topic, message) on the home page and on `/legal`. First send asks FormSubmit to confirm `info@whiskeytangologistics.com`.
