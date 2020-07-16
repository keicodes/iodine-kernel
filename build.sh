#!/bin/bash

IODINE_LINUX_REPOSITORY="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
IODINE_LINUX_VERSION="v5.7.9"

IODINE_LINUX_BRANCH=`echo $IODINE_LINUX_VERSION | sed 's/[^.]*$/x/'`
IODINE_LINUX_CONFIG="configs/$IODINE_LINUX_BRANCH/$IODINE_LINUX_VERSION"

IODINE_COMPILER="gcc"
IODINE_MAKE_FLAGS="-j`nproc`"

IODINE_CONFIG_PACKAGE="bindeb-pkg"
IODINE_CONFIG_NATIVE="y"
IODINE_CONFIG_SIGNING="n"
IODINE_CONFIG_SIGNING_KEY="certs/kernel_key.pem"

#	If the compiler path is wrong, fall back to GCC
iodine-check-compiler() {
	if ! type $IODINE_COMPILER >/dev/null 2>&1; then
		echo "  - no compiler found for $IODINE_COMPILER, falling back to GCC"

		if ! type gcc >/dev/null 2>&1; then
			echo "  - couldn't find GCC, is it installed?"

			exit 1
		else
			IODINE_COMPILER="gcc"
		fi
	fi
}

#	Clone the chosen branch if doesn't exists
iodine-get-kernel() {
	if [ ! -d "linux" ]; then
		echo " [*] Fetching kernel $IODINE_LINUX_VERSION"

		git clone --single-branch --depth 1 -b $IODINE_LINUX_VERSION $IODINE_LINUX_REPOSITORY
	else
		echo " [*] Kernel folder found"

		if [ `make -sC linux kernelversion` == ${IODINE_LINUX_VERSION[@]:1} ]; then
			echo "  - kernel version matches"
		else
			echo "  - it appears to be a different kernel version, exiting"

			exit 1
		fi
	fi
}

#	Apply various patches considering the kernel branch
iodine-apply-patches() {
	echo " [*] Applying patches $IODINE_LINUX_BRANCH"

	for patch in patches/$IODINE_LINUX_BRANCH/*.patch; do
		git apply --numstat --directory linux $patch
	done
}

iodine-set-config() {
	if [ -f "$IODINE_LINUX_CONFIG" ]; then
		cp $IODINE_LINUX_CONFIG .config
	else
		echo "Couldn't find any config, exiting"

		exit 1
	fi
}

#	Start the build
iodine-build() {
	echo " [*] Building"

	iodine-set-config()

	cd linux

	if [ $IODINE_CONFIG_NATIVE == "y" ]; then
		echo "  - using $IODINE_COMPILER compiler set to native CPU, make $IODINE_MAKE_FLAGS"

		scripts/config --enable CONFIG_MNATIVE
		scripts/config --disable GENERIC_CPU
	else
		echo "  - using $IODINE_COMPILER compiler set to generic CPU, make $IODINE_MAKE_FLAGS"

		scripts/config --enable GENERIC_CPU
		scripts/config --disable CONFIG_MNATIVE
	fi

	if [ $IODINE_CONFIG_SIGNING = "y" ]; then
		echo "  - signing enabled with $IODINE_CONFIG_SIGNING_KEY key"

		scripts/config --enable CONFIG_MODULE_SIG_ALL
		scripts/config --set-str CONFIG_MODULE_SIG_KEY $IODINE_CONFIG_SIGNING_KEY
	else
		scripts/config --disable CONFIG_MODULE_SIG_ALL
	fi

	make HOSTCC=$IODINE_COMPILER CC=$IODINE_COMPILER $IODINE_MAKE_FLAGS LOCALVERSION="-iodine" $IODINE_CONFIG_PACKAGE
}

#	TODO: use getops to build a comprehensive list of usable options

iodine-check-compiler

iodine-get-kernel

iodine-apply-patches

iodine-build

