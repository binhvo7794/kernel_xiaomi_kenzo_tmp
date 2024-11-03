#!/bin/bash

#
# Configure defualt value:
# CPU = use all cpu for build
# CHAT = chat telegram for push build. use id.
#
CPU=$(nproc --all)
SUBNAME="none"

sudo apt-get install --no-install-recommends -y binutils git make bc bison openssl curl zip kmod cpio flex libelf-dev libssl-dev libtfm-dev libc6-dev device-tree-compiler ca-certificates python3 xz-utils libc6-dev aria2 build-essential ccache libssl-dev gcc-aarch64* gcc-arm* python2

#
# Add support cmd:
# --cpu= for cpu used to compile
# --key= for bot key used to push.
# --name= for custom subname of kernel
#
config() {

    arg1=${1}

    case ${1} in
        "--cpu="* )
            CPU="--cpu="
            CPU=${arg1#"$CPU"}
        ;;
        "--key="* )
            KEY="--key="
            KEY=${arg1#"$KEY"}
        ;;
        "--name="* )
            SUBNAME="--name="
            SUBNAME=${arg1#"$SUBNAME"}
        ;;
    esac
}

arg1=${1}
arg2=${2}
arg3=${3}

config ${1}
config ${2}
config ${3}

echo "Config for resource of environment done."
echo "CPU for build: $CPU"
echo "NAME of kernel: $SUBNAME"

# Clean stuff
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    rm -rf "out/arch/arm64/boot/Image.gz-dtb"
fi

# start build date
DATE=$(date +"%Y%m%d-%H%M")

# Compiler type
TOOLCHAIN_DIRECTORY="tc"

# Build defconfig
DEFCONFIG="kenzo_defconfig"

# Check for compiler
if [ ! -d "$TOOLCHAIN_DIRECTORY" ]; then
    mkdir $TOOLCHAIN_DIRECTORY
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $TOOLCHAIN_DIRECTORY/gcc-64
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $TOOLCHAIN_DIRECTORY/gcc-32
fi


#
# Build start with clang
#
PATH="$(pwd)/$TOOLCHAIN_DIRECTORY/gcc-64/bin:$(pwd)/$TOOLCHAIN_DIRECTORY/gcc-32/bin:${PATH}"
make ARCH=arm64 $DEFCONFIG
make -j$CPU ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu-


if [ $SUBNAME == "none" ]; then
    SUBNAME=$DATE
fi

cp arch/arm64/boot/Image.gz-dtb AnyKernel3
curl bashupload.com -T arch/arm64/boot/Image.gz-dtb
cd AnyKernel3
zip -r9 ../Kenzo-$SUBNAME.zip * -x .git README.md *placeholder
cd ..
rm -rf anykernel
echo "The path of the kernel.zip is: $(pwd)/Rave-$SUBNAME.zip"

if [ ! $KEY == "none" ]; then
    curl -F chat_id="$CHAT" \
        -F caption="-Keep Rave" \
        -F document=@"Kenzo-$SUBNAME.zip" \
        https://api.telegram.org/bot"$KEY"/sendDocument

    curl -s -X POST "https://api.telegram.org/bot"${1}"/sendMessage" \
	    -d chat_id="$CHAT" \
	    -d "disable_web_page_preview=true" \
	    -d "parse_mode=html" \
	    -d text="<b>Branch</b>: <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Last Commit</b>: <code>$(git log --pretty=format:'%s' -1)</code>%0A<b>Kernel Version</b>: <code>$(make kernelversion)</code>"
fi
