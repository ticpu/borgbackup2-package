#!/bin/sh

export VERSION=${2-2.0.0b7}

build_for () {
	local version="$1"
	local distro="$2"
	local distro_short="${distro#*:}"
	local image="borgbackup2-$distro_short"
	local mount_path
	DISTRO="$distro" envsubst < Containerfile.template > Containerfile
	podman build -t "borgbackup2-$distro_short" .
	trap "podman image unmount $image" RETURN
	mount_path=$(podman unshare podman image mount $image)
	cp "$mount_path/borgbackup2-$version.tar.gz" "borgbackup2-$distro_short-$version.tar.gz"
}

if [ -z "$1" ];
then
	for i in debian:bullseye debian:bookworm ubuntu:jammy
	do
		build_for "$VERSION" "$i"
	done
else
	build_for "$VERSION" "$1"
fi
