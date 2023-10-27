#!/bin/sh

log () {
	echo "$*" >&2
}

get_latest_version () {
	curl -s \
		-H 'Accept: application/vnd.github+json' \
		-H 'X-GitHub-Api-Version: 2022-11-28' \
		'https://api.github.com/repos/borgbackup/borg/releases?per_page=1' | \
			jq -r '.[0].tag_name'
}

build_for () {
	local version="$1"; shift
	local distro="$1"; shift
	local distro_short="${distro#*:}"
	local image="borgbackup2-$distro_short"
	local archive="borgbackup2-$distro_short-$version.tar.gz"
	local mount_path
	if [ ! -s "$archive" ]; then
		DISTRO="$distro" VERSION="$version" \
			envsubst < Containerfile.template > Containerfile
		podman build -t "borgbackup2-$distro_short" .
		trap "podman image unmount $image" RETURN
		mount_path=$(podman unshare podman image mount $image)
		cp "$mount_path/borgbackup2-$version.tar.gz" \
			"$archive"
		cp "$mount_path/md5sums" "md5sums-$distro_short"
		cp "$mount_path/size" "size-$distro_short"
	fi
	deb_for "$archive" "$distro_short"
	rm -f Containerfile
}

deb_for () {
	local archive="$1"; shift
	local debfile="../borgbackup2-venv_${version}~${distro_short}-1_amd64.deb"
	local distro_short="$1"; shift
	local size

	read -r size < "size-${distro_short}"

	cd "$(dirname "$0")"
	rm -rf deb/
	mkdir -p deb/
	pushd deb/ >/dev/null
	mv "../md5sums-$distro_short" md5sums
	VERSION="$version" SIZE="$size" DISTRO="$distro_short" \
		envsubst < ../control.template > control
	tar -czf ../control.tar.gz *
	rm *
	mv ../control.tar.gz .
	mv "../$archive" data.tar.gz
	echo '2.0' > debian-binary
	rm -f "$debfile"
	ar -rcs "$debfile" \
		debian-binary control.tar.gz data.tar.gz
	popd >/dev/null
	rm "size-${distro_short}"
	rm -r deb/
}

main () {
	local distro="${1}"
	local version

	if [ -n "$2" ]; then
		version="${2}"
	else
		version="$(get_latest_version)"
	fi

	log "building packages for version $version"
	if [ -z "$distro" ];
	then
		local distros="debian:bullseye debian:bookworm ubuntu:jammy"
		log "for distros $distros"
		for i in $distros
		do
			build_for "$version" "$i"
		done
	else
		log "for distro $distro"
		build_for "$version" "$distro"
	fi
}

set -e
main "$1" "$2"
