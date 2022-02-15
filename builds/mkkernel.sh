#!/bin/bash
source ./utils.sh
"$BINPATH/send_message.sh" "$CHID" "Compiling kernel for RM6785"

# Install necessary packages
sudo apt-get -qqy install \
  build-essential \
  libncurses-dev \
  bison \
  flex \
  libssl-dev \
  libelf-dev \
  git \
  bc

# Add toolchains into $PATH
export PATH=$HOME/toolchains/proton-clang/bin:$PATH

# Clone and chown
sudo git clone https://github.com/Hakimi0804/android_kernel_realme_mt6785.git \
  /android_kernel_realme_mt6785.git --depth=1
sudo chown -R "$(whoami)" /android_kernel_realme_mt6785.git

# Build
cd /android_kernel_realme_mt6785.git || exit 1
make_flags=(
    O=out
    CC=clang
    ARCH=arm64
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    -j"$(nproc)"
)
make mrproper
make "${make_flags[@]}" RM6785_defconfig
make "${make_flags[@]}"

# Upload kernel with `transfer`
    # Copy files
    cd /tmp || exit 1
    cp /android_kernel_realme_mt6785/out/arch/arm64/boot/Image .
    cp /android_kernel_realme_mt6785/out/arch/arm64/boot/Image.gz .
    cp /android_kernel_realme_mt6785/out/arch/arm64/boot/Image.gz-dtb .

    # Setup `transfer`
    curl -sL https://git.io/file-transfer | sh

    # Upload
    IMG_LINK=$(./transfer -q gof /tmp/Image)
    IMG-GZ_LINK=$(./transfer -q gof /tmp/Image.gz)
    IMG-GZ-DTB_LINK=$(./transfer -q gof /tmp/Image.gz-dtb)

    # Send link to telegram
    "$BINPATH/send_message.sh" "$CHID" "Done, link:
Image       : $IMG_LINK
Image.gz    : $IMG-GZ_LINK
Image.gz-dtb: $IMG-GZ-DTB_LINK
"


