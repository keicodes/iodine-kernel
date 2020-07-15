#!/bin/sh

echo " [*] Setting environment"

IODINE_LINUX_REPOSITORY="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
IODINE_LINUX_VERSION="v5.7.8"

IODINE_COMPILER="gcc-10"
IODINE_MAKE_FLAGS="-j`nproc`"

IODINE_SIGNING="n"
IODINE_SIGNING_KEY="certs/kernel_key.pem"

if [ ! -d "linux" ]; then
	echo " [*] Fetching kernel $IODINE_LINUX_VERSION"

	git clone -b $IODINE_LINUX_VERSION --single-branch $IODINE_LINUX_REPOSITORY
else
	echo " [-] Kernel folder found"
fi

echo " [*] Applying patches"

for patch in patches/*.patch; do
	patch -sNp1 -dlinux < $patch
done

cd linux

if [ $IODINE_SIGNING = "y" ]; then
	echo " [*] Signing enabled"

	scripts/config --enable CONFIG_MODULE_SIG_ALL
	scripts/config --set-str CONFIG_MODULE_SIG_KEY $IODINE_SIGNING_KEY
else
	scripts/config --disable CONFIG_MODULE_SIG_ALL
fi

cp "../configs/$IODINE_LINUX_VERSION" .config

echo " [*] Building (using $IODINE_COMPILER $IODINE_MAKE_FLAGS)"

make HOSTCC=$IODINE_COMPILER CC=$IODINE_COMPILER $IODINE_MAKE_FLAGS bindeb-pkg

