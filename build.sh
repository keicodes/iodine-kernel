#!/bin/bash

IODINE_LINUX_REPOSITORY="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
IODINE_LINUX_VERSION="v5.7.9"

IODINE_LINUX_BRANCH=`echo $IODINE_LINUX_VERSION | sed 's/[^.]*$/x/'`
IODINE_LINUX_CONFIG="configs/$IODINE_LINUX_BRANCH/$IODINE_LINUX_VERSION"

IODINE_CONFIG_PACKAGE="bindeb-pkg"
IODINE_CONFIG_GENERIC="n"
IODINE_CONFIG_SIGNING="n"
IODINE_CONFIG_SIGNING_KEY="certs/kernel_key.pem"

#	Configurations

IODINE_COMPILER="gcc"
IODINE_MAKE_FLAGS="-j`nproc`"

#	Command line tool usage info
iodine-usage() {
	echo -e "Usage:\n"
	echo -e "  -h, --help				Prints these options\n"
	echo -e "  -g, --get-kernel			Clones the Linux repository only\n"
	echo -e "  -p, --apply-patches			Applies patches only\n"
	echo -e "  -b, --build				Runs over all the commands to build the kernel\n"
	echo -e "  --deb, --rpm				Packages to either DEB or RPM\n"
	echo -e "  --generic				Optimizes for generic x86_64 cpus\n"
	echo -e "  --sign-modules			Signing facility"
}

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
		patch -sNp1 -dlinux < $patch
	done
}

iodine-set-config() {
	if [ -f ".config" ]; then
		echo "  - found an existing config, skipping"
	else
		if [ -f $IODINE_LINUX_CONFIG ]; then
			cp "../$IODINE_LINUX_CONFIG" ".config"
		else
			echo "  - couldn't find any config, exiting"

			exit 1
		fi

		if [ $IODINE_CONFIG_GENERIC == "y" ]; then
			echo "  - optimizations set to generic"

			scripts/config --enable GENERIC_CPU
			scripts/config --disable CONFIG_MNATIVE
		else
			echo "  - optimizations set to native"

			scripts/config --enable CONFIG_MNATIVE
			scripts/config --disable GENERIC_CPU
		fi

		if [ $IODINE_CONFIG_SIGNING = "y" ]; then
			echo "  - signing enabled with $IODINE_CONFIG_SIGNING_KEY key"

			scripts/config --enable CONFIG_MODULE_SIG_ALL
			scripts/config --set-str CONFIG_MODULE_SIG_KEY $IODINE_CONFIG_SIGNING_KEY
		else
			scripts/config --disable CONFIG_MODULE_SIG_ALL
		fi
	fi
}

#	Start the build
iodine-build() {
	echo " [*] Building $IODINE_CONFIG_PACKAGE"

	cd linux

	iodine-set-config

	echo "  - using $IODINE_COMPILER, make $IODINE_MAKE_FLAGS"

	make HOSTCC=$IODINE_COMPILER CC=$IODINE_COMPILER $IODINE_MAKE_FLAGS LOCALVERSION="-iodine" $IODINE_CONFIG_PACKAGE
}

getopt -T &>/dev/null

OPTS=`getopt  -n "$0" -o gpbh --long "get-kernel,apply-patches,generic,sign-modules,deb,rpm,build,help" -- "$@"`

if [ $? != 0 ] || [ -z $1 ]; then iodine-usage >&2; exit 1; fi

eval set -- "$OPTS"

while true;
do
	case "$1" in
		-g|--get-kernel)
			iodine-get-kernel

			break;;
		-p|--apply-patches)
			iodine-apply-patches

			break;;
		--generic)
			IODINE_CONFIG_GENERIC="y"

			shift;;
		--sign-modules)
			IODINE_CONFIG_SIGNING="y"

			shift;;
		--deb)
			IODINE_CONFIG_PACKAGE="bindeb-pkg"

			shift;;
		--rpm)
			IODINE_CONFIG_PACKAGE="binrpm-pkg"

			shift;;
		-b|--build)
			iodine-check-compiler

			iodine-get-kernel

			iodine-apply-patches

			IODINE_BUILD="y"

			shift;;
		-h|--help|?)
			iodine-usage

			break;;
		--)
			shift

			break;;
	esac
done

if [[ -n $IODINE_BUILD ]]; then
	iodine-build
fi

