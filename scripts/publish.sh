#!/bin/sh
# Publish dist/ to the Cloudflare Pages project that already owns the domain.
# Requires CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID.
set -eu
cd "$(dirname "$0")/.."
test -d dist
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"

body=$(mktemp)
code=$(curl -sS -o "$body" -w "%{http_code}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects")

if [ "$code" != "200" ]; then
  echo "Cloudflare project list returned HTTP $code" >&2
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("errors") or d.get("message") or "no error body")' "$body" >&2
  rm -f "$body"
  exit 1
fi
projects=$(cat "$body")
rm -f "$body"

name=$(printf '%s' "$projects" | python3 -c '
import json, sys
data = json.load(sys.stdin)
want = "whiskeytangologistics.com"
if not data.get("success"):
    sys.stderr.write("Cloudflare project list failed\n")
    sys.exit(1)
found = []
for project in data.get("result") or []:
    domains = project.get("domains") or []
    names = []
    for domain in domains:
        if isinstance(domain, str):
            names.append(domain)
        elif isinstance(domain, dict):
            names.append(domain.get("name") or domain.get("domain") or "")
    if want in names:
        found.append(project["name"])
print(found[0] if found else "")
')

if [ -z "$name" ]; then
  echo "No Pages project on this account has whiskeytangologistics.com" >&2
  printf '%s' "$projects" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(p.get("name","?") for p in d.get("result") or []))' >&2
  exit 1
fi

echo "Deploying to Pages project: $name"
npx --yes wrangler@3 pages deploy dist --project-name="$name" --branch=main --commit-dirty=true
