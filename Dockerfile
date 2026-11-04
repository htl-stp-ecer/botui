# Build environment for botui: Flutter, flutterpi_tool and the aarch64 cross compiler.
# build.py builds this image and runs the whole build inside it, so nothing has to be
# installed on the host. Keep the Flutter version in line with .fvmrc.
FROM ghcr.io/cirruslabs/flutter:3.38.7

ENV DEBIAN_FRONTEND=noninteractive

# aarch64 cross compiler (the raccoon_ring bridge), dpkg-deb (comes with dpkg), python for build.py
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# Git dependencies are written as git@github.com:...; there is no ssh key in the container.
RUN git config --global url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global --add safe.directory '*'
