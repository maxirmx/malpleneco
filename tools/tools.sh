#!/bin/bash

# Copyright (c) 2025 [Maxim Samsonov](https://www.sw.consulting).
# Copyright (c) 2024-2025 [Ribose Inc](https://www.ribose.com).
# All rights reserved.
# This file is a part of the Malpeneco project.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -o errexit -o pipefail -o noclobber -o nounset

: "${LOCAL_BUILDS:=/tmp/malpeneco}"
: "${CMAKE_VERSION:=3.28.6-1}"
: "${RUBY_VERSION:=3.3.7}"
: "${RUBY_INSTALL_VERSION:=0.9.3}"
: "${OPENSSL_VERSION:=3.4.1}"
: "${ZSTD_VERSION:=1.5.5}"
: "${ARCH:=x64}"

install_cmake() {
  echo "Running install_cmake for CMake version ${CMAKE_VERSION} for ${ARCH}"
  local cmake_install="${LOCAL_BUILDS}/cmake"
  mkdir -p "${cmake_install}"
  pushd "${cmake_install}"
  wget -nv "https://github.com/xpack-dev-tools/cmake-xpack/releases/download/v${CMAKE_VERSION}/xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz"
  tar -zxf "xpack-cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz" --directory /usr --strip-components=1 --skip-old-files
  popd
  rm -rf "${cmake_install}"
}

install_ruby() {
  echo "Running ruby_install version ${RUBY_INSTALL_VERSION} for Ruby ${RUBY_VERSION}"
  local ruby_install=${LOCAL_BUILDS}/ruby_install
  mkdir -p "${ruby_install}"
  pushd "${ruby_install}"
  wget -nv "https://github.com/postmodern/ruby-install/releases/download/v${RUBY_INSTALL_VERSION}/ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  tar -xzvf "ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  cd "ruby-install-${RUBY_INSTALL_VERSION}"
  make install
  ruby-install --system ruby "${RUBY_VERSION}" -- --without-gmp --disable-dtrace --disable-debug-env --disable-install-doc CC="${CC}"
  popd
  rm -rf "${ruby_install}"
}

install_openssl() {
  echo "Running install_openssl for OpenSSL version ${OPENSSL_VERSION}"
  local openssl_install="${LOCAL_BUILDS}/openssl"
  mkdir -p "${openssl_install}"
  pushd "${openssl_install}"
  
  # Download OpenSSL source
  wget -nv "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
  tar -zxf "openssl-${OPENSSL_VERSION}.tar.gz"
  cd "openssl-${OPENSSL_VERSION}"
  
  # Configure with default OpenSSL directory locations
  CC="${CC}" ./config --prefix=/usr/local --openssldir=/usr/local/ssl 
  
  #no-shared
  
  # Build and install
  make -j "$(nproc)"
  make install

  # Update ld cache
  ldconfig
  
  # Verify installation
  echo "OpenSSL installation complete. Version installed: $(openssl version)"
  
  popd
  rm -rf "${openssl_install}"
}

install_zstd() {
  echo "Running install_zstd for zstd version ${ZSTD_VERSION}"
  local zstd_install="${LOCAL_BUILDS}/zstd"
  mkdir -p "${zstd_install}"
  pushd "${zstd_install}"
  
  # Download zstd source
  wget -nv "https://github.com/facebook/zstd/archive/v${ZSTD_VERSION}.tar.gz" -O "zstd-${ZSTD_VERSION}.tar.gz"
  tar -zxf "zstd-${ZSTD_VERSION}.tar.gz"
  cd "zstd-${ZSTD_VERSION}"
  
  # Build static libraries only (no shared libraries)
  make -j "$(nproc)" lib-mt
  make -C lib ZSTD_LIB_MINIFY=1 install-static
  
  # Install the CLI tools (static build)
  cd programs
  LDFLAGS="-static" make -j "$(nproc)"
  cp zstd /usr/local/bin/
  
  # Create necessary pkg-config file for libzstd.pc
  mkdir -p /usr/local/lib/pkgconfig
  cat > /usr/local/lib/pkgconfig/libzstd.pc << EOF
Name: libzstd
Description: Fast lossless compression algorithm library
Version: ${ZSTD_VERSION}
URL: https://facebook.github.io/zstd/
Libs: -L/usr/local/lib -lzstd
Cflags: -I/usr/local/include
EOF
  
  # Verify installation
  echo "zstd installation complete. Version installed: $(zstd --version | head -n1)"
  
  popd
  rm -rf "${zstd_install}"
}

DIR0=$( dirname "$0" )
DIR_TOOLS=$( cd "$DIR0" && pwd )

echo "Running tools.sh with args: $* DIR_TOOLS: ${DIR_TOOLS}"

"$@"