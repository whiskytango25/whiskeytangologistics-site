#!/bin/sh
# Publish dist/ to the Cloudflare Pages project that already owns the domain.
# Requires CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID.
# Does not create a project and does not move the custom domain.
set -eu
cd "$(dirname "$0")/.."
test -d dist
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"

target=$(mktemp)
trap 'rm -f "$target"' EXIT

python3 - "$target" <<'PY'
import json, os, sys, urllib.error, urllib.parse, urllib.request

out_path = sys.argv[1]
token = os.environ["CLOUDFLARE_API_TOKEN"]
account = os.environ["CLOUDFLARE_ACCOUNT_ID"]
APEX = "whiskeytangologistics.com"
WANT = {APEX, "www.whiskeytangologistics.com"}

def request(path):
    url = "https://api.cloudflare.com/client/v4" + path
    req = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            return res.status, json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            data = json.loads(raw)
        except Exception:
            data = {"errors": [{"message": raw[:400]}]}
        return e.code, data
    except Exception as e:
        return 0, {"errors": [{"message": str(e)}]}

def err(data):
    errors = data.get("errors") if isinstance(data, dict) else None
    if errors:
        return "; ".join(str(item.get("message") or item) for item in errors)
    if isinstance(data, dict) and data.get("message"):
        return str(data["message"])
    return "request failed"

def add_host(found, value):
    if not isinstance(value, str):
        return
    host = value.strip().lower().rstrip(".")
    if "://" in host:
        host = host.split("://", 1)[1]
    host = host.split("/", 1)[0]
    if host:
        found.add(host)

def collect(obj, found):
    if isinstance(obj, str):
        add_host(found, obj)
    elif isinstance(obj, dict):
        for key in ("name", "domain", "hostname", "url", "subdomain"):
            if key in obj:
                add_host(found, obj[key])
        for key in ("domains", "aliases", "custom_domains"):
            if key in obj and obj[key] is not None:
                collect(obj[key], found)
    elif isinstance(obj, list):
        for item in obj:
            collect(item, found)

def get_results(path):
    """Return (http_code, list_of_result_items). Follows result_info pages."""
    items = []
    page = 1
    while page <= 10:
        sep = "&" if "?" in path else "?"
        url = path if page == 1 else f"{path}{sep}page={page}"
        code, data = request(url)
        if code != 200 or not isinstance(data, dict) or not data.get("success"):
            if page == 1:
                return code, [], err(data)
            print(f"  page {page} of {path} failed: HTTP {code} {err(data)}", file=sys.stderr)
            break
        result = data.get("result")
        if isinstance(result, dict):
            items.append(result)
            break
        items.extend(result or [])
        info = data.get("result_info") or {}
        total = info.get("total_pages") or 1
        if page >= total or not result:
            break
        page += 1
    return 200, items, ""

acode, accounts, amessage = get_results("/accounts")
if acode != 200 or not accounts:
    print(
        f"Account list HTTP {acode}: {amessage}. Using the configured account only.",
        file=sys.stderr,
    )
    accounts = [{"id": account, "name": "configured"}]
else:
    print("Accounts this token can see:", file=sys.stderr)
    for item in accounts:
        print(f"  {item.get('name')}  {item.get('id')}", file=sys.stderr)

pages_hosts = {}  # pages.dev hostname -> (project, branch, account id)
matches = []
any_projects = False

for acct in accounts:
    acct_id = acct.get("id") or ""
    label = acct.get("name") or acct_id
    pcode, projects, pmessage = get_results(f"/accounts/{acct_id}/pages/projects")
    if pcode != 200:
        print(f"{label}: project list HTTP {pcode}: {pmessage}", file=sys.stderr)
        continue
    any_projects = True
    print(f"{label}: {len(projects)} Pages projects", file=sys.stderr)
    for project in projects:
        name = project.get("name") or ""
        branch = project.get("production_branch") or "main"
        hosts = set()
        collect(project.get("domains"), hosts)
        collect(project.get("canonical_deployment"), hosts)
        collect(project.get("latest_deployment"), hosts)
        sub = (project.get("subdomain") or "").strip().lower()
        if sub:
            hosts.add(sub if sub.endswith(".pages.dev") else sub + ".pages.dev")

        dcode, domains, dmessage = get_results(
            f"/accounts/{acct_id}/pages/projects/{urllib.parse.quote(name)}/domains"
        )
        if dcode == 200:
            collect(domains, hosts)
            domain_note = "domains ok"
        else:
            domain_note = f"domains HTTP {dcode}: {dmessage}"

        for host in list(hosts):
            if host.endswith(".pages.dev"):
                pages_hosts.setdefault(host, (name, branch, acct_id))

        shown = ", ".join(sorted(hosts)) if hosts else "(none)"
        print(f"  {name}  branch={branch}  {domain_note}  hosts={shown}", file=sys.stderr)

        for host in hosts:
            if host in WANT or host.endswith("." + APEX):
                rank = 0 if host == APEX else 1
                matches.append((rank, name, branch, host, acct_id))

if not any_projects and not matches:
    print("No Pages projects were visible to this token.", file=sys.stderr)
    sys.exit(1)

chosen = None
if matches:
    matches.sort()
    _, name, branch, host, acct_id = matches[0]
    print(
        f"Matched {host} on project {name} (account {acct_id}, production branch {branch})",
        file=sys.stderr,
    )
    chosen = (name, branch, acct_id)
else:
    print("No Pages custom domain is whiskeytangologistics.com. Checking DNS.", file=sys.stderr)
    zcode, zones, zmessage = get_results("/zones?name=" + APEX)
    if zcode != 200:
        print(f"Zone lookup HTTP {zcode}: {zmessage}", file=sys.stderr)
    elif not zones:
        print("This token cannot see a zone named whiskeytangologistics.com.", file=sys.stderr)
    else:
        zid = zones[0].get("id")
        zacct = zones[0].get("account", {}).get("id") or account
        print("Zone is visible to this token. DNS records:", file=sys.stderr)
        for host in (APEX, "www." + APEX):
            rcode, recs, rmessage = get_results(f"/zones/{zid}/dns_records?name={host}")
            if rcode != 200:
                print(f"  {host}: HTTP {rcode} {rmessage}", file=sys.stderr)
                continue
            if not recs:
                print(f"  {host}: no records", file=sys.stderr)
            for rec in recs:
                content = (rec.get("content") or "").strip().lower().rstrip(".")
                print(
                    f"  {rec.get('type')} {rec.get('name')} -> {rec.get('content')} proxied={rec.get('proxied')}",
                    file=sys.stderr,
                )
                target = pages_hosts.get(content)
                if target and chosen is None:
                    print(f"DNS for {host} points at Pages project {target[0]}. Using that.", file=sys.stderr)
                    chosen = target
                elif content.endswith(".pages.dev") and chosen is None:
                    print(
                        f"DNS points at {content}, which is not one of this token's Pages projects.",
                        file=sys.stderr,
                    )

if not chosen:
    print(
        "Stopped. No project this token can see owns whiskeytangologistics.com. Not creating one.",
        file=sys.stderr,
    )
    sys.exit(1)

with open(out_path, "w") as handle:
    handle.write(chosen[0] + "\n" + chosen[1] + "\n" + chosen[2] + "\n")
PY

name=$(sed -n '1p' "$target")
branch=$(sed -n '2p' "$target")
account_id=$(sed -n '3p' "$target")
test -n "$name"
test -n "$branch"
test -n "$account_id"
export CLOUDFLARE_ACCOUNT_ID="$account_id"
echo "Deploying to Pages project: $name (account $account_id, branch $branch)"
npx --yes wrangler@3 pages deploy dist --project-name="$name" --branch="$branch" --commit-dirty=true
