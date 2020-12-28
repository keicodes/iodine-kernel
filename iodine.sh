#!/bin/bash

IODINE_LINUX_REPOSITORY="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
IODINE_LINUX_VERSION="v5.10.3"

IODINE_LINUX_FOLDER="linux-$IODINE_LINUX_VERSION"
IODINE_LINUX_BRANCH=`echo $IODINE_LINUX_VERSION | sed 's/.[0-9]\{1,3\}//3; s/$/.x/'`

IODINE_LINUX_CONFIG="configs/$IODINE_LINUX_BRANCH.config"
IODINE_LINUX_PATCHES="patches/$IODINE_LINUX_BRANCH"

IODINE_CONFIG_PACKAGE="rpm-pkg"
IODINE_CONFIG_GENERIC="y"
IODINE_CONFIG_SIGNING="n"

#	Configurations

IODINE_CC="gcc"
IODINE_CXX="g++"

IODINE_MAKE_FLAGS="-j`nproc`"
IODINE_COMPILER_FLAGS="HOSTCC=$IODINE_CC CC=$IODINE_CC HOSTCXX=$IODINE_CXX"

IODINE_CONFIG_SIGNING_KEY="certs/kernel_key.pem"

#	Command line tool usage info
iodine-usage() {
	echo -e "Usage:\n"
	echo -e "  -h, --help				Print these options\n"
	echo -e "  -g, --get-kernel			Clone the Linux repository only\n"
	echo -e "  -p, --apply-patches			Apply patches only\n"
	echo -e "  -c, --set-config			Generate the kernel config with the selected options\n"
	echo -e "  -b, --build				Run over all the commands to build the kernel\n"
	echo -e "  --llvm				Use LLVM"
	echo -e "  --deb, --rpm				Package to either DEB or RPM\n"
	echo -e "  --generic				Optimize for generic x86_64 CPUs\n"
	echo -e "  --sign-modules			Signing facility"
}

#	If the compiler path is wrong, fall back to GCC
iodine-check-compiler() {
	if ! type $IODINE_CC >/dev/null 2>&1; then
		echo "  - no C compiler found for $IODINE_CC, falling back to gcc"

		if ! type gcc >/dev/null 2>&1; then
			echo "  - couldn't find GCC, is it installed?"

			exit 1
		else
			IODINE_CC="gcc"
		fi
	fi

	if ! type $IODINE_CXX >/dev/null 2>&1; then
		echo "  - no C++ compiler found for $IODINE_CXX, falling back to g++"

		if ! type g++ >/dev/null 2>&1; then
			echo "  - couldn't find g++, is it installed?"

			exit 1
		else
			IODINE_CXX="gcc"
		fi
	fi
}

#	Clone the chosen branch if doesn't exists
iodine-get-kernel() {
	if [ ! -d "$IODINE_LINUX_FOLDER" ]; then
		echo " [*] Fetching kernel $IODINE_LINUX_VERSION"

		git clone --single-branch --depth 1 -b $IODINE_LINUX_VERSION $IODINE_LINUX_REPOSITORY $IODINE_LINUX_FOLDER
	else
		echo " [*] Kernel folder found"

		#	Fix no patchset version
		if [ `echo ${IODINE_LINUX_VERSION[@]:1} | tr -dc '.' | wc -c` -lt 2 ]; then
			IODINE_LINUX_CORRECT_VERSION="${IODINE_LINUX_VERSION[@]:1}.0"
		else
			IODINE_LINUX_CORRECT_VERSION="${IODINE_LINUX_VERSION[@]:1}"
		fi

		if [ `make -sC $IODINE_LINUX_FOLDER kernelversion` == $IODINE_LINUX_CORRECT_VERSION ]; then
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

	for patch in $IODINE_LINUX_PATCHES/*.patch; do
		patch -sNp1 -d$IODINE_LINUX_FOLDER < $patch
	done
}

#	Copies the config and sets various options
iodine-set-config() {
	if [[ -f "$IODINE_LINUX_FOLDER/.config" ]]; then
		echo "  - using pre-existing config"
	else
		if [[ -f "$IODINE_LINUX_CONFIG" ]]; then
			cp "$IODINE_LINUX_CONFIG" "$IODINE_LINUX_FOLDER/.config"
		else
			echo "  - couldn't find any config, exiting"

			exit 1
		fi
	fi

	if [[ $IODINE_USE_LLVM == "y" ]]; then
		#	This is just set to show the config settings
		IODINE_HOSTCC="clang"
		IODINE_CC="clang"
		IODINE_CXX="clang++"

		IODINE_COMPILER_FLAGS="LLVM=1"

		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --disable INIT_STACK_ALL
	fi

	if [[ $IODINE_CONFIG_GENERIC == "y" ]]; then
		IODINE_BUILD_TARGET="generic"

		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --disable CONFIG_MNATIVE
		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --enable GENERIC_CPU
	else
		#	If it's not a generic build and both generic and native are disabled, then we got a specific type selected, leave it as it is
		if [[ `./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --state GENERIC_CPU` == "n" ]] && [[ `./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --state CONFIG_MNATIVE` == "n" ]]; then
			IODINE_BUILD_TARGET="custom"
		else
			IODINE_BUILD_TARGET="native"

			./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --disable GENERIC_CPU
			./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --enable CONFIG_MNATIVE
		fi
	fi

	if [[ $IODINE_CONFIG_SIGNING = "y" ]]; then
		echo "  - signing enabled with $IODINE_CONFIG_SIGNING_KEY key"

		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --enable CONFIG_MODULE_SIG_ALL
		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --set-str CONFIG_MODULE_SIG_KEY $IODINE_CONFIG_SIGNING_KEY
	else
		./$IODINE_LINUX_FOLDER/scripts/config --file "$IODINE_LINUX_FOLDER/.config" --disable CONFIG_MODULE_SIG_ALL
	fi
}

#	Start the build
iodine-build() {
	echo " [*] Building $IODINE_CONFIG_PACKAGE"

	iodine-set-config

	cd $IODINE_LINUX_FOLDER

	echo "  - using $IODINE_CC/$IODINE_CXX, CPU optimizations set to $IODINE_BUILD_TARGET, make $IODINE_MAKE_FLAGS"

	make $IODINE_COMPILER_FLAGS $IODINE_MAKE_FLAGS LOCALVERSION="-iodine" $IODINE_CONFIG_PACKAGE
}

getopt -T &>/dev/null

OPTS=`getopt  -n "$0" -o gpcbh --long "get-kernel,apply-patches,set-config,llvm,generic,sign-modules,deb,rpm,build,help" -- "$@"`

if [ $? != 0 ] || [ -z $1 ]; then iodine-usage >&2; exit 1; fi

eval set -- "$OPTS"

while true;
do
	case "$1" in
		-g|--get-kernel)
			iodine-get-kernel

			shift;;
		-p|--apply-patches)
			iodine-apply-patches

			shift;;
		-c|--set-config)
			iodine-set-config

			shift;;
		--llvm)
			IODINE_USE_LLVM="y"

			shift;;
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

