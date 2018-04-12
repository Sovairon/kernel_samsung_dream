#!/bin/bash
# Kernel Build Script

BUILD_WHERE=$(pwd)
BUILD_KERNEL_DIR=$BUILD_WHERE
BUILD_ROOT_DIR=$BUILD_KERNEL_DIR/..
BUILD_KERNEL_OUT_DIR=$BUILD_ROOT_DIR/kernel_out/KERNEL_OBJ
PRODUCT_OUT=$BUILD_ROOT_DIR/kernel_out

# Default parameter
DEVICE="dreamlte"
TOOLCHAIN="7"
KERNEL_DTBTOOL="./dtbTool"

case $DEVICE in
    "dreamlte") KERNEL_DEFCONFIG=dash_defconfig; export LOCALVERSION="-DashKernel-Dream" ;;
    "dream2lte") KERNEL_DEFCONFIG=dash2_defconfig; export LOCALVERSION="-DashKernel-Dream2" ;;
    *) die "Invalid defconfig!";
esac 

case $TOOLCHAIN in
    "4.9") KERNEL_TOOLCHAIN=aarch64-linux-android-; export PATH=$PATH:/home/michael/android/toolchain/aarch64-linux-android/bin/ ;;
    "7") KERNEL_TOOLCHAIN=aarch64-linux-gnu-; export PATH=$PATH:/home/michael/android/toolchain/aarch64-linux-gnu/bin/ ;;
    *) die "Invalid toolchain!";
esac 

BUILD_CROSS_COMPILE=$KERNEL_TOOLCHAIN
BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`

KERNEL_IMG=$PRODUCT_OUT/Image
DTIMG=$PRODUCT_OUT/dt.img

DTBTOOL=$KERNEL_DTBTOOL


FUNC_COMPILE_KERNEL()
{
	echo "----------------------------------------------"
	echo " 1. GENERATE DEFCONFIG"
	echo " "
	echo "build config="$KERNEL_DEFCONFIG ""
	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER ARCH=arm64 \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			$KERNEL_DEFCONFIG || exit -1
	cp $BUILD_KERNEL_OUT_DIR/.config $BUILD_KERNEL_DIR/arch/arm64/configs/$KERNEL_DEFCONFIG
	echo " "
	echo " Done!"
	echo " "
	echo "----------------------------------------------"
	echo " 2. GENERATE DTB"
	echo " "
	rm -rf $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/dts
	make dtbs -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER ARCH=arm64 \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo " "
	echo " Done!"
	echo " "
	echo "----------------------------------------------"
	echo " 3. COMPILE KERNEL"
	echo " "
	rm $KERNEL_IMG $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image
	rm -rf $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/dts

if [ "$USE_CCACHE" ]
then
	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER ARCH=arm64 \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			CC="ccache "$BUILD_CROSS_COMPILE"gcc" CPP="ccache "$BUILD_CROSS_COMPILE"gcc -E" || exit -1
else
	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER ARCH=arm64 \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
fi

	cp $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image $KERNEL_IMG
	echo "Made Kernel image: $KERNEL_IMG , Done!"
	echo " "
	echo "----------------------------------------------"
	echo " 4. GENERATE DT.IMG"
	rm $DTIMG
	$DTBTOOL -s 2048 -d $BUILD_KERNEL_OUT_DIR/arch/arm64/boot/dts -o $DTIMG
	if [ -f "$DTIMG" ]; then
		echo "Made DT image: $DTIMG"
	fi
	echo " Done!"
}

# MAIN FUNCTION
(
    START_TIME=`date +%s`

    FUNC_COMPILE_KERNEL

    FUNC_GENERATE_DTIMG

    END_TIME=`date +%s`

    let "ELAPSED_TIME=$END_TIME-$START_TIME"
    echo "Total compile time is $ELAPSED_TIME seconds"
) 2>&1

if [ ! -f "$KERNEL_IMG" ]; then
  exit -1
fi
