#!/bin/sh
# Shared helpers for Haiku bootstrap URL allowlisting and SHA-256 checks.
# Sourced by other haiku/scripts. Not meant to be run directly.

haiku_sha256_file() {
	f=$1
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$f" | awk '{print $1}'
		return
	fi
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$f" | awk '{print $1}'
		return
	fi
	if command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$f" | awk '{print $NF}'
		return
	fi
	echo "no sha256 tool found (need sha256sum, shasum, or openssl)" >&2
	return 1
}

# Load haiku/bootstrap.lock without overriding variables already set in the environment.
haiku_load_bootstrap_lock() {
	lock=${HAIKU_BOOTSTRAP_LOCK:-}
	if [ -z "$lock" ]; then
		here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
		lock="$here/../bootstrap.lock"
	fi
	if [ ! -f "$lock" ]; then
		echo "missing bootstrap lock: $lock" >&2
		return 1
	fi
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
		''|\#*) continue ;;
		esac
		key=${line%%=*}
		val=${line#*=}
		case "$key" in
		HAIKU_BOOTSTRAP_URL|HAIKU_BOOTSTRAP_SHA256|HAIKU_BOOTSTRAP_TAG|HAIKU_BOOTSTRAP_ALLOWED_HOSTS|HAIKU_BOOTSTRAP_ALLOWED_REPOS)
			eval "cur=\${$key-}"
			if [ -z "$cur" ]; then
				export "$key=$val"
			fi
			;;
		esac
	done < "$lock"
}

# Allow only https://github.com/<allowed-repo>/releases/download/... URLs.
haiku_url_allowed() {
	url=$1
	case "$url" in
	https://github.com/*) ;;
	*)
		echo "bootstrap URL must be https://github.com/... (got $url)" >&2
		return 1
		;;
	esac

	rest=${url#https://github.com/}
	owner=${rest%%/*}
	rest=${rest#*/}
	repo=${rest%%/*}
	rest=${rest#*/}
	case "$rest" in
	releases/download/*) ;;
	*)
		echo "bootstrap URL must be a GitHub release download (got $url)" >&2
		return 1
		;;
	esac

	pair="${owner}/${repo}"
	allowed=${HAIKU_BOOTSTRAP_ALLOWED_REPOS:-korli/go}
	if [ -n "${GITHUB_REPOSITORY:-}" ]; then
		case ",$allowed," in
		*",$GITHUB_REPOSITORY,"*) ;;
		*) allowed="${allowed},${GITHUB_REPOSITORY}" ;;
		esac
	fi

	oldifs=$IFS
	IFS=,
	found=0
	for a in $allowed; do
		if [ "$a" = "$pair" ]; then
			found=1
			break
		fi
	done
	IFS=$oldifs
	if [ "$found" -ne 1 ]; then
		echo "bootstrap URL repo $pair is not allowlisted (allowed: $allowed)" >&2
		return 1
	fi
	return 0
}

haiku_verify_sha256() {
	file=$1
	want=$2
	if [ -z "$want" ]; then
		echo "refusing to use bootstrap without SHA-256 pin" >&2
		return 1
	fi
	got=$(haiku_sha256_file "$file") || return 1
	if [ "$got" != "$want" ]; then
		echo "bootstrap SHA-256 mismatch for $file" >&2
		echo "  want: $want" >&2
		echo "  got:  $got" >&2
		return 1
	fi
	echo "bootstrap SHA-256 OK ($got)"
}
