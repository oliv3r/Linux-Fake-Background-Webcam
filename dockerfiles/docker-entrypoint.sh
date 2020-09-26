#!/usr/bin/dumb-init /bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2020 Olliver Schinagl <oliver@schinagl.nl>
#
# A beginning user should be able to docker run image bash (or sh) without
# needing to learn about --entrypoint
# https://github.com/docker-library/official-images#consistency

set -eux

BODYPIXSOCKET="/run/bodypix.sock"

# run command if it is not starting with a "-" and is an executable in PATH
if [ "${#}" -gt 0 ] && \
   [ "${1#-}" = "${1}" ] && \
   command -v "${1}" > "/dev/null" 2>&1; then
	# Execute requested executable
	exec "${@}"
else
	if [ ! -c "/dev/webcam" ]; then
		echo "Missing '/dev/webcam'. Use '--device /dev/videoX:/dev/webcam'"
		exit 1
	fi
	if [ ! -c "/dev/v4l2loopback" ]; then
		echo "Missing '/dev/v4l2loopback'. Use '--device /dev/videoX:/dev/v4l2loopback'"
		exit 1
	fi
	if [ ! -d "/images" ]; then
		echo "Missing images. Use '-v /path/to/images:/images'"
		exit 1
	fi

	BPPORT="${BPPORT:-${BODYPIXSOCKET}}"
	node "/bodypix/app.js" &
	if [ "${BPPORT}" = "${BODYPIXSOCKET}" ]; then
		while [ ! -S "${BPPORT}" ]; do
			sleep 1
		done
	else
		# How can we establish that bodypix is running?
		# while "$(echo "PING" | nc localhost 9000" != "PONG")"; do
			sleep 3
		# done
	fi
	python3 -u "/fakecam/fake.py" \
	        --webcam-path="/dev/webcam" \
		--v4l2loopback-path="/dev/v4l2loopback" \
		--image-folder="/images/" \
		"${@}"
fi

exit 0
