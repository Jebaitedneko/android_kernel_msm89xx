#!/bin/bash

# Prepared by Jebaitedneko <jebaitedneko@gmail.com>

KERNEL_ROOT_DIR=$(pwd)

TARGET_ARCH="arm64"
KERNEL_CONFIG="holland2_defconfig"
ZIP_NAME="holland2"
ENABLE_CCACHE="1"
TOOLCHAIN="3" # 1) gcc-4.9 2) eva-gcc-11 3) proton-clang-13 4) sdclang-12.1 5) aosp-clang-r383902
DISABLE_LLD="0"
DISABLE_IAS="1"
DISABLE_LLD_IAS="0"
BUILD_MODULES="0"
DO_SYSTEMLESS="1"
BUILD_DTBO_IMG="0"
PATCH_PERMISSIVE="0"
PATCH_CLASSPATH="0"
RAMOOPS_MEMRESERVE="1"
DTC_EXT_FOR_DTC="0"

OUT_BOOT_DIR="$KERNEL_ROOT_DIR/out/arch/$TARGET_ARCH/boot"
DTBO_DIR="$OUT_BOOT_DIR/dts/qcom"

TOOLCHAIN_DIR="$KERNEL_ROOT_DIR/../../toolchains"

ANYKERNEL_DIR="$TOOLCHAIN_DIR/anykernel3"
ANYKERNEL_SRC="https://github.com/osm0sis/AnyKernel3"

DTBTOOL_DIR="$TOOLCHAIN_DIR/dtbtool"
DTBTOOL_SRC="https://raw.githubusercontent.com/LineageOS/android_system_tools_dtbtool/lineage-18.1/dtbtool.c"
DTBTOOL_ARGS="-v -s 2048 -o $OUT_BOOT_DIR/dt.img"

UFDT_DIR="$TOOLCHAIN_DIR/libufdt"
UFDT_SRC="https://android.googlesource.com/platform/system/libufdt"
UFDT_ARGS="create dtbo.img --page_size=4096 $DTBO_DIR/*.dtbo"

BUILD_MODULES_DIR="$KERNEL_ROOT_DIR/out/modules"

git_clone() {
	if [ ! -d "${3}" ]; then
		mkdir -p "${3}"
		git clone \
			--depth=1 \
			--single-branch \
			"${1}" \
			-b "${2}" \
			"${3}"
	fi
}

check_updates_from_github() {
	REMOTE_SHA=$(curl -s "${1}/commits/${2}" | grep "Copy the full SHA" | grep -oE "[0-9a-f]{40}" | head -n1)
	LOCAL_SHA=$( ( cd "${3}"; [ -d ".git" ] && git log | grep -oE "[0-9a-f]{40}" | head -n1 ) )
	echo -e "\nREMOTE: ${REMOTE_SHA}"
	echo -e "\nLOCAL:  ${LOCAL_SHA}"
	if [[ "${REMOTE_SHA}" != "${LOCAL_SHA}" ]]; then
		echo -e "\nSHA Mismatch. Fetching Upstream...\n"
		( rm -rf "${3}"; git clone --depth=1 "${1}" --single-branch -b "${2}" "${3}" )
	else
		echo -e "\nSHA Matched.\n"
	fi
}

get_gcc-4.9() {

	CC_IS_CLANG=0
	CC_IS_GCC=1

	TC_64="$TOOLCHAIN_DIR/los-gcc-4.9-64"
	REPO_64="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"
	BRANCH_64="lineage-18.1"

	TC_32="$TOOLCHAIN_DIR/los-gcc-4.9-32"
	REPO_32="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"
	BRANCH_32="lineage-18.1"

	git_clone "${REPO_64}" "${BRANCH_64}" "${TC_64}"
	check_updates_from_github "${REPO_64}" "${BRANCH_64}" "${TC_64}"

	git_clone "${REPO_32}" "${BRANCH_32}" "${TC_32}"
	check_updates_from_github "${REPO_32}" "${BRANCH_32}" "${TC_32}"

	CROSS="$TC_64/bin/aarch64-linux-android-"
	CROSS_ARM32="$TC_32/bin/arm-linux-androideabi-"

	MAKEOPTS=""

}

get_gcc-4.9-aosp() {

	CC_IS_CLANG=0
	CC_IS_GCC=1

	TC_64="$TOOLCHAIN_DIR/gcc-4.9-64"
	REPO_64="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9"
	BRANCH_64="master"

	TC_32="$TOOLCHAIN_DIR/gcc-4.9-32"
	REPO_32="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"
	BRANCH_32="master"

	git_clone "${REPO_64}" "${BRANCH_64}" "${TC_64}"
	check_updates_from_github "${REPO_64}" "${BRANCH_64}" "${TC_64}"

	git_clone "${REPO_32}" "${BRANCH_32}" "${TC_32}"
	check_updates_from_github "${REPO_32}" "${BRANCH_32}" "${TC_32}"

	CROSS="$TC_64/bin/aarch64-linux-android-"
	CROSS_ARM32="$TC_32/bin/arm-linux-androideabi-"

	MAKEOPTS=""
}

get_eva_gcc-12.0() {

	CC_IS_CLANG=0
	CC_IS_GCC=1

	TC_64="$TOOLCHAIN_DIR/gcc-12.0-64"
	REPO_64="https://github.com/mvaisakh/gcc-arm64"
	BRANCH_64="gcc-master"

	TC_32="$TOOLCHAIN_DIR/gcc-12.0-32"
	REPO_32="https://github.com/mvaisakh/gcc-arm"
	BRANCH_32="gcc-master"

	git_clone "${REPO_64}" "${BRANCH_64}" "${TC_64}"
	check_updates_from_github "${REPO_64}" "${BRANCH_64}" "${TC_64}"

	git_clone "${REPO_32}" "${BRANCH_32}" "${TC_32}"
	check_updates_from_github "${REPO_32}" "${BRANCH_32}" "${TC_32}"

	CROSS="$TC_64/bin/aarch64-elf-"
	CROSS_ARM32="$TC_32/bin/arm-eabi-"

	MAKEOPTS="LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip \
				OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
				HOSTAR=llvm-ar HOSTLD=ld.lld"

	if [[ $DISABLE_LLD == "1" ]]; then
		MAKEOPTS="AR=llvm-ar NM=llvm-nm STRIP=llvm-strip \
					OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
					HOSTAR=llvm-ar"
	fi

}

get_proton_clang-13.0() {

	CC_IS_GCC=0
	CC_IS_CLANG=1

	TC="$TOOLCHAIN_DIR/proton-clang-13.0"
	REPO="https://github.com/kdrag0n/proton-clang"
	BRANCH="master"

	git_clone "${REPO}" "${BRANCH}" "${TC}"
	check_updates_from_github "${REPO}" "${BRANCH}" "${TC}"

	CROSS="$TC/bin/aarch64-linux-gnu-"
	CROSS_ARM32="$TC/bin/arm-linux-gnueabi-"

	MAKEOPTS="CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm STRIP=llvm-strip \
				OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
				HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTAS=llvm-as HOSTLD=ld.lld"

	if [[ $DISABLE_LLD == "1" ]]; then
		MAKEOPTS="CC=clang AR=llvm-ar AS=llvm-as NM=llvm-nm STRIP=llvm-strip \
					OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
					HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTAS=llvm-as"
	else
		if [[ $DISABLE_IAS == "1" ]]; then
			MAKEOPTS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip \
						OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
						HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld"
		else
			if [[ $DISABLE_LLD_IAS == "1" ]]; then
				MAKEOPTS="CC=clang AR=llvm-ar AS=llvm-as NM=llvm-nm STRIP=llvm-strip \
							OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
							HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTAS=llvm-as"
			fi
		fi
	fi

}


get_sdclang-12.1() {

	get_proton_clang-13.0

	CC_IS_GCC=0
	CC_IS_CLANG=1

	TC="$TOOLCHAIN_DIR/sdclang-12.1"
	REPO="https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang"
	BRANCH="ruby-12"

	git_clone "${REPO}" "${BRANCH}" "${TC}"
	check_updates_from_github "${REPO}" "${BRANCH}" "${TC}"

	TRIPLE="$TC/bin/aarch64-linux-gnu-"

	MAKEOPTS="CLANG_TRIPLE=$TRIPLE CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm STRIP=llvm-strip \
				OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
				HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTAS=llvm-as HOSTLD=ld.lld"

	if [[ $DISABLE_LLD_IAS == "1" ]]; then
		MAKEOPTS="CLANG_TRIPLE=$TRIPLE CC=clang AR=llvm-ar NM=llvm-nm STRIP=llvm-strip \
					OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
					HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar"
	fi

}

get_aosp_clang-r383902() {

	get_gcc-4.9-aosp

	CC_IS_GCC=0
	CC_IS_CLANG=1

	TC="$TOOLCHAIN_DIR/aosp-clang-r383902"

	if [ ! -d "$TC/bin" ]; then
		mkdir -p "$TC"
		(
			cd "$TC"
			if [ ! -f "clang-r383902.tar.gz" ]; then
				wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r383902.tar.gz
				tar -xf clang-r383902.tar.gz -C .
			fi
		)
	fi

	TRIPLE="$TC/bin/aarch64-linux-gnu-"
	MAKEOPTS="CLANG_TRIPLE=$TRIPLE CC=clang"

}

make_dtboimg() {

	(
		cd "$OUT_BOOT_DIR"
		[ ! -d "$UFDT_DIR" ] && git clone --depth=1 --single-branch "$UFDT_SRC" "$UFDT_DIR"
		chmod +x "$UFDT_DIR"/utils/src/mkdtboimg.py
		echo -e "\nMaking dtbo.img..."
		echo -e "\npython3 $UFDT_DIR/utils/src/mkdtboimg.py $(echo "$UFDT_ARGS")"
		python3 "$UFDT_DIR"/utils/src/mkdtboimg.py $(echo "$UFDT_ARGS")
		echo -e "\nDone."
	)

}

make_dtimg() {

	[ ! -d "$DTBTOOL_DIR" ] && wget -q "$DTBTOOL_SRC" -O "$DTBTOOL_DIR"/dtbtool.c
	cc "$DTBTOOL_DIR"/dtbtool.c -o "$OUT_BOOT_DIR"/dts

	(
		cd "$OUT_BOOT_DIR"/dts
		echo -e "\nMaking dt.img using dtbtool..."
		echo -e "\ndtbtool $(echo "$DTBTOOL_ARGS")"
		dtbtool $(echo "$DTBTOOL_ARGS")
		echo -e "\nDone."
	)

}

build() {

	echo -e "\nApplying Temp YYLLOC Workarounds..."
	YYLL1="$KERNEL_ROOT_DIR/scripts/dtc/dtc-lexer.lex.c_shipped"
	YYLL2="$KERNEL_ROOT_DIR/scripts/dtc/dtc-lexer.l"
	[ -f "$YYLL1" ] && sed -i "s/extern YYLTYPE yylloc/YYLTYPE yylloc/g;s/YYLTYPE yylloc/extern YYLTYPE yylloc/g" "$YYLL1"
	[ -f "$YYLL2" ] && sed -i "s/extern YYLTYPE yylloc/YYLTYPE yylloc/g;s/YYLTYPE yylloc/extern YYLTYPE yylloc/g" "$YYLL2"
	echo -e "\nDone."

	case $TOOLCHAIN in
		1) echo -e "\nSelecting GCC-4.9...\n" && get_gcc-4.9 ;;
		2) echo -e "\nSelecting EVA-GCC-12.0...\n" && get_eva_gcc-12.0 ;;
		3) echo -e "\nSelecting PROTON-CLANG-13.0...\n" && get_proton_clang-13.0 ;;
		4) echo -e "\nSelecting SDCLANG-12.1...\n" && get_sdclang-12.1 ;;
		5) echo -e "\nSelecting AOSP-CLANG-R383902...\n" && get_aosp_clang-r383902 ;;
	esac

	if [[ $TARGET_ARCH = "arm" ]]; then
		CROSS_COMPILE=$CROSS_ARM32
	else
		CROSS_COMPILE=$CROSS
	fi
	export CROSS_COMPILE

	export CROSS_COMPILE_ARM32=$CROSS_ARM32

	if [[ ! -f ${TRIPLE%/*}/clang ]]; then
		echo -e "TRIPLE unset. Assuming Bare-Metal...\n"
	else
		echo -e "$( "${TRIPLE%/*}"/clang -v )" && IS_AOSP_CLANG="1"
	fi

	if [[ ! -f ${CROSS_COMPILE}gcc ]]; then
		if [[ ! -f ${CROSS_COMPILE%/*}/clang ]]; then
			if [[ $IS_AOSP_CLANG == "1" ]]; then
				echo -e "\nARM64: Detected AOSP Binutils: ${CROSS_COMPILE}"
			else
				echo -e "\nCROSS_COMPILE not set properly." && exit
			fi
		else
			echo -e "$( "${CROSS_COMPILE%/*}"/clang -v )"
		fi
	else
		echo -e "$( "${CROSS_COMPILE}"gcc -v )"
	fi

	if [[ ! -f ${CROSS_COMPILE_ARM32}gcc ]]; then
		if [[ ! -f ${CROSS_COMPILE_ARM32%/*}/clang ]]; then
			if [[ $IS_AOSP_CLANG == "1" ]]; then
				echo -e "\nARM32: Detected AOSP Binutils: ${CROSS_COMPILE_ARM32}"
			else
				echo -e "\nCROSS_COMPILE_ARM32 not set properly." && exit
			fi
		else
			echo -e "$( "${CROSS_COMPILE_ARM32%/*}"/clang -v )"
		fi
	else
		echo -e "$( "${CROSS_COMPILE_ARM32}"gcc -v )"
	fi

	if [ -d out ]; then
			rm -rf out
	else
			mkdir -p out
	fi

	BUILD_START=$(date +"%s")

	echo -e "\n\nmake $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH $KERNEL_CONFIG\n\n"
	make $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH $KERNEL_CONFIG || exit

	if [[ $BUILD_MODULES == "1" ]]; then
		BUILD_HAS_MODULES=$( [[ $(grep "=m" "$KERNEL_ROOT_DIR"/out/.config | wc -c) -gt 0 ]] && echo 1 )
		if [[ $BUILD_HAS_MODULES == "1" ]]; then
			echo -e "\nHAS MODULES: $BUILD_HAS_MODULES"
		else
			echo -e "\nHAS MODULES: $BUILD_HAS_MODULES"
		fi
	fi

	if [[ $BUILD_DTBO_IMG == "1" ]]; then
		BUILD_HAS_DTBO=$( [[ $(grep "DT_OVERLAY=y" "$KERNEL_ROOT_DIR"/out/.config | wc -c) -gt 0 ]] && echo 1 )
		if [[ $BUILD_HAS_DTBO == "1" ]]; then
			echo -e "\nHAS DTBO: $BUILD_HAS_DTBO"
		else
			echo -e "\nHAS DTBO: $BUILD_HAS_DTBO"
		fi
	fi

	if [[ $DTC_EXT_FOR_DTC == "1" ]]; then
		DTC_EXT="$(which dtc) -q"
		DTC_FLAGS="-q"
		echo -e "\nUsing $DTC_EXT $DTC_FLAGS for DTC...\n"
		export DTC_EXT DTC_FLAGS
	fi

	if [[ ${1} != "" && ${1} == "dtbs" ]]; then
		echo -e "\nMaking only DTBs as requested...\n"
		echo -e "\n\nmake CC=clang O=out ARCH=$TARGET_ARCH dtbs\n\n"
		make CC=clang O=out ARCH=$TARGET_ARCH CONFIG_BUILD_ARM64_DT_OVERLAY=y dtbs && exit || exit
	fi

	if [[ $CC_IS_GCC == "1" ]]; then

		if [[ $ENABLE_CCACHE == "1" ]]; then
			echo -e "\nUsing ccache with gcc"
			echo -e "\n\nmake CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH CC=\"ccache ${CROSS_COMPILE}gcc\" -j$(($(nproc)+8))\n\n"
			make CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH CC="ccache ${CROSS_COMPILE}gcc" -j$(($(nproc)+8)) || exit
		else
			echo -e "\nNot using ccache with gcc"
			echo -e "\n\nmake CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH -j$(($(nproc)+8))\n\n"
			make CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH -j$(($(nproc)+8)) || exit
		fi
	else
		if [[ $CC_IS_CLANG == "1" ]]; then

			if [[ $ENABLE_CCACHE == "1" ]]; then
				echo -e "\nUsing ccache with clang"
				echo -e "\n\nmake CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH CC=\"ccache clang\" -j$(($(nproc)+8))\n\n"
				make CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH CC="ccache clang" -j$(($(nproc)+8)) || exit
			else
				echo -e "\nNot using ccache with clang"
				echo -e "\n\nmake CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH -j$(($(nproc)+8))\n\n"
				make CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH -j$(($(nproc)+8)) || exit
			fi
		fi
	fi

	if [[ $BUILD_HAS_DTBO == "1" ]]; then
		make_dtboimg
	fi

	if [[ $BUILD_MODULES == "1" ]]; then
		if [[ $BUILD_HAS_MODULES == "1" ]]; then
			if [ -d "$BUILD_MODULES_DIR" ]; then
					rm -rf "$BUILD_MODULES_DIR"
			else
					mkdir -p "$BUILD_MODULES_DIR"
			fi
			echo -e "\nMaking modules..."
			echo -e "\n\nmake CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH INSTALL_MOD_PATH=$BUILD_MODULES_DIR INSTALL_MOD_STRIP=1 modules_install\n\n"

			make CONFIG_DEBUG_SECTION_MISMATCH=y $(echo -e "$MAKEOPTS") O=out ARCH=$TARGET_ARCH INSTALL_MOD_PATH="$BUILD_MODULES_DIR" INSTALL_MOD_STRIP=1 modules_install || exit

			echo -e "\nDone."
		fi
	fi

	[ -d "$KERNEL_ROOT_DIR"/.git ] && git restore "$YYLL1" "$YYLL2"

	DIFF=$(($(date +"%s") - BUILD_START))
	echo -e "\n\nBuild completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds.\n\n"

}

build_zip() {

	[ ! -d "$ANYKERNEL_DIR" ] && git clone --depth=1 --single-branch "$ANYKERNEL_SRC" -b master "$ANYKERNEL_DIR"

	echo -e "\nCleaning Up Old AnyKernel Remnants...\n"
	PRE_FILES="Image
	Image-dtb
	Image.gz
	Image.gz-dtb
	dt.img
	dtbo.img"

	echo "$PRE_FILES" | \
	while read -r f;
	do
		if [[ -f $ANYKERNEL_DIR/$f ]]; then
			echo -e "Removing OLD $ANYKERNEL_DIR/$f" && rm "$ANYKERNEL_DIR"/"$f"
		fi;
	done
	echo -e "\nDone."

	echo -e "
	# AnyKernel3 Ramdisk Mod Script
	# osm0sis @ xda-developers

	properties() { '
	kernel.string=test
	device.name1=generic
	do.modules=0
	do.systemless=0
	do.cleanup=1
	do.cleanuponabort=0
	'; }

	block=/dev/block/bootdevice/by-name/boot;
	is_slot_device=0;
	ramdisk_compression=auto;

	. tools/ak3-core.sh;

	set_perm_recursive 0 0 755 644 \$ramdisk/*;
	set_perm_recursive 0 0 750 750 \$ramdisk/init* \$ramdisk/sbin;

	dump_boot;

	if [ -d \$ramdisk/overlay ]; then
		rm -rf \$ramdisk/overlay;
	fi;

	# patch_cmdline firmware_class.path firmware_class.path=/vendor/firmware_mnt/image
	# patch_cmdline androidboot.selinux androidboot.selinux=permissive
	# patch_cmdline ramoops_memreserve ramoops_memreserve=8M

	write_boot;
	" > "$ANYKERNEL_DIR"/anykernel.sh

	if [[ $BUILD_MODULES == "1" ]]; then
		BUILD_HAS_MODULES=$( [[ $(grep "=m" "$KERNEL_ROOT_DIR"/out/.config | wc -c) -gt 0 ]] && echo 1 )
		if [[ $BUILD_HAS_MODULES == "1" ]]; then
			sed -i "s/do.modules=0/do.modules=1/g" "$ANYKERNEL_DIR"/anykernel.sh
		fi
	fi

	if [[ $DO_SYSTEMLESS == "1" ]]; then
		sed -i "s/do.systemless=0/do.systemless=1/g" "$ANYKERNEL_DIR"/anykernel.sh
	fi

	if [[ $PATCH_PERMISSIVE == "1" ]]; then
		sed -i "s/# patch_cmdline androidboot.selinux/patch_cmdline androidboot.selinux/g" "$ANYKERNEL_DIR"/anykernel.sh
	fi

	if [[ $PATCH_CLASSPATH == "1" ]]; then
		sed -i "s/# patch_cmdline firmware_class.path/patch_cmdline firmware_class.path/g" "$ANYKERNEL_DIR"/anykernel.sh
	fi

	if [[ $RAMOOPS_MEMRESERVE == "1" ]]; then
		sed -i "s/# patch_cmdline ramoops_memreserve/patch_cmdline ramoops_memreserve/g" "$ANYKERNEL_DIR"/anykernel.sh
	fi

	sed -i "s/kernel.string=generic/kernel.string=$ZIP_NAME/g" "$ANYKERNEL_DIR"/anykernel.sh
	sed -i "s/device.name1=generic/device.name1=$ZIP_NAME/g" "$ANYKERNEL_DIR"/anykernel.sh

	chmod +x "$ANYKERNEL_DIR"/anykernel.sh

	(
		echo -e "\nZipping...\n"

		cd "$ANYKERNEL_DIR"

		if [[ ! -f $OUT_BOOT_DIR/Image.gz-dtb ]]; then
			if [[ ! -f $OUT_BOOT_DIR/Image.gz ]]; then
				if [[ ! -f $OUT_BOOT_DIR/Image-dtb ]]; then
					if [[ ! -f $OUT_BOOT_DIR/Image ]]; then
						echo -e "\nNo kernels found. Exiting..." && exit
					else
						cp "$OUT_BOOT_DIR"/Image "$ANYKERNEL_DIR" && make_dtimg
					fi
				else
					cp "$OUT_BOOT_DIR"/Image-dtb "$ANYKERNEL_DIR"
				fi
			else
				cp "$OUT_BOOT_DIR"/Image.gz "$ANYKERNEL_DIR" && make_dtimg
			fi
		else
			cp "$OUT_BOOT_DIR"/Image.gz-dtb "$ANYKERNEL_DIR"
		fi

		if [[ ! -f $OUT_BOOT_DIR/dtbo.img ]]; then
			if [[ ! -f $OUT_BOOT_DIR/dt.img ]]; then
				echo -e "\nUsing appended dtb..."
			else
				cp "$OUT_BOOT_DIR"/dt.img "$ANYKERNEL_DIR"
			fi
		else
			cp "$OUT_BOOT_DIR"/dtbo.img "$ANYKERNEL_DIR"
		fi

		ZIP_PREFIX_KVER=$(grep Linux "$KERNEL_ROOT_DIR"/out/.config | cut -f 3 -d " ")
		ZIP_POSTFIX_DATE=$(date +%d-%h-%Y-%R:%S | sed "s/:/./g")

		if [[ $BUILD_MODULES == "1" ]]; then
			BUILD_HAS_MODULES=$( [[ $(grep "=m" "$KERNEL_ROOT_DIR"/out/.config | wc -c) -gt 0 ]] && echo 1 )
		fi

		if [[ $BUILD_HAS_MODULES == "1" ]]; then
			MOD_DIR="$ANYKERNEL_DIR"/modules/system/lib/modules
			K_MOD_DIR="$KERNEL_ROOT_DIR"/out/modules
			[ -d "$MOD_DIR" ] && rm -rf "$MOD_DIR" && mkdir -p "$MOD_DIR"
			[ ! -d "$K_MOD_DIR" ] && mkdir -p "$K_MOD_DIR"
			find "$K_MOD_DIR" -type f -iname "*.ko" -exec cp {} "$MOD_DIR" \;
			zip -r ${ZIP_NAME}_"${ZIP_PREFIX_KVER}"_"${ZIP_POSTFIX_DATE}".zip . -x '*.git*' '*patch*' '*ramdisk*' 'LICENSE' 'README.md'
		else
			zip -r ${ZIP_NAME}_"${ZIP_PREFIX_KVER}"_"${ZIP_POSTFIX_DATE}".zip . -x '*.git*' '*modules*' '*patch*' '*ramdisk*' 'LICENSE' 'README.md'
		fi

		[[ $(find "$KERNEL_ROOT_DIR"/out -maxdepth 1 -type f -iname "*.zip") ]] && rm "$KERNEL_ROOT_DIR"/out/*.zip
		mv ./*.zip "$KERNEL_ROOT_DIR"/out

		echo -e "\nDone."
		echo -e "\n$(md5sum "$KERNEL_ROOT_DIR"/out/*.zip)"
	)

}

case "${1}" in
	"build")
		build ;;
	"zip")
		build_zip ;;
	"dtboimg")
		make_dtboimg ;;
	*)
		build "${1}" && build_zip ;;
esac
