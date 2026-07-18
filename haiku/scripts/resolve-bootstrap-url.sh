#!/bin/sh
# Resolve a pinned Haiku bootstrap URL and SHA-256.
# Prints: URL<TAB>SHA256
#
# Priority:
# 1. HAIKU_BOOTSTRAP_URL + HAIKU_BOOTSTRAP_SHA256 (both required)
# 2. HAIKU_BOOTSTRAP_PIN_TAG on this repo (asset + SHA256SUMS from that release)
# 3. haiku/bootstrap.lock seed
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/bootstrap-common.sh"

explicit_url=${HAIKU_BOOTSTRAP_URL:-}
explicit_sha=${HAIKU_BOOTSTRAP_SHA256:-}
pin_tag=${HAIKU_BOOTSTRAP_PIN_TAG:-}
repo=${GITHUB_REPOSITORY:-}

if [ -n "$explicit_url" ]; then
	if [ -z "$explicit_sha" ]; then
		echo "HAIKU_BOOTSTRAP_URL set without HAIKU_BOOTSTRAP_SHA256" >&2
		exit 1
	fi
	# Still load lock for allowlist defaults.
	haiku_load_bootstrap_lock || true
	haiku_url_allowed "$explicit_url"
	printf '%s\t%s\n' "$explicit_url" "$explicit_sha"
	exit 0
fi

haiku_load_bootstrap_lock

fetch_release_asset() {
	owner_repo=$1
	tag=$2
	if ! command -v curl >/dev/null 2>&1; then
		return 1
	fi
	api="https://api.github.com/repos/${owner_repo}/releases/tags/${tag}"
	json=$(curl -fsSL "$api" 2>/dev/null) || return 1
	asset_url=$(printf '%s' "$json" | sed -n 's/.*"browser_download_url": "\([^"]*haiku-amd64-bootstrap\.tbz\)".*/\1/p' | head -n 1)
	sums_url=$(printf '%s' "$json" | sed -n 's/.*"browser_download_url": "\([^"]*SHA256SUMS\)".*/\1/p' | head -n 1)
	if [ -z "$asset_url" ] || [ -z "$sums_url" ]; then
		return 1
	fi
	haiku_url_allowed "$asset_url"
	tmp=$(mktemp)
	curl -fsSL -o "$tmp" "$sums_url"
	base=$(basename "$asset_url")
	want=$(awk -v b="$base" '
		$2 == b || $2 == ("*" b) || $2 == ("./" b) { print $1; exit }
	' "$tmp")
	rm -f "$tmp"
	if [ -z "$want" ]; then
		echo "SHA256SUMS for $tag missing entry for $base" >&2
		return 1
	fi
	printf '%s\t%s\n' "$asset_url" "$want"
}

if [ -n "$pin_tag" ] && [ -n "$repo" ]; then
	if out=$(fetch_release_asset "$repo" "$pin_tag"); then
		printf '%s\n' "$out"
		exit 0
	fi
	echo "pinned tag $pin_tag not usable on $repo, falling back to lock" >&2
fi

url=${HAIKU_BOOTSTRAP_URL:-}
sha=${HAIKU_BOOTSTRAP_SHA256:-}
if [ -z "$url" ] || [ -z "$sha" ]; then
	echo "bootstrap.lock missing HAIKU_BOOTSTRAP_URL or HAIKU_BOOTSTRAP_SHA256" >&2
	exit 1
fi
haiku_url_allowed "$url"
printf '%s\t%s\n' "$url" "$sha"
