#!/bin/sh

echo " [*] Setting environment"

IODINE_LINUX_REPOSITORY="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
IODINE_LINUX_VERSION="v5.7.8"

IODINE_COMPILER="gcc-10"
IODINE_MAKE_FLAGS="-j`nproc`"

IODINE_SIGNING="n"
IODINE_SIGNING_KEY="certs/kernel_key.pem"

#	If the compiler path is wrong, fall back to GCC

if ! type $IODINE_COMPILER >/dev/null 2>&1; then
	echo "  - No compiler found for $IODINE_COMPILER, falling back to GCC"

	if ! type gcc >/dev/null 2>&1; then
		echo "  - Couldn't find GCC, is it installed?"
	else
		IODINE_COMPILER="gcc"
	fi
fi

#	Clone the chosen branch if doesn't exists

if [ ! -d "linux" ]; then
	echo " [*] Fetching kernel $IODINE_LINUX_VERSION"

	git clone -b $IODINE_LINUX_VERSION --single-branch --depth 1 $IODINE_LINUX_REPOSITORY
else
	echo " [*] Kernel folder found"
fi

echo " [*] Applying patches"

for patch in patches/*.patch; do
	patch -sNp1 -dlinux < $patch
done

cp "configs/$IODINE_LINUX_VERSION" linux/.config

cd linux

if [ $IODINE_SIGNING = "y" ]; then
	echo " [*] Signing enabled"

	scripts/config --enable CONFIG_MODULE_SIG_ALL
	scripts/config --set-str CONFIG_MODULE_SIG_KEY $IODINE_SIGNING_KEY
else
	scripts/config --disable CONFIG_MODULE_SIG_ALL
fi

echo " [*] Building (using $IODINE_COMPILER $IODINE_MAKE_FLAGS)"

make HOSTCC=$IODINE_COMPILER CC=$IODINE_COMPILER $IODINE_MAKE_FLAGS LOCALVERSION="-iodine" bindeb-pkg
