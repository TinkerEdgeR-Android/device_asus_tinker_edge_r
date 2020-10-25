#!/bin/bash
usage()
{
    echo "USAGE: [-o] [-u] [-r] [-v VERSION_NAME] [-n BUILD_NUMBER]"
    echo "No ARGS means use default build option"
    echo "WHERE: -o = generate ota package       "
    echo "       -u = generate update.img        "
    echo "       -r = pack the release"
    echo "       -v = set build version name for output image folder"
    echo "       -n = set build number"
    exit 1
}

BUILD_UPDATE_IMG=false
BUILD_OTA=false
#BUILD_VERSION="IMAGES"
PACK_RELEASE=false

BUILD_NUMBER="eng"-"$USER"-"$(date  +%Y%m%d.%H%M)"
RELEASE_NAME=Tinker_Edge_R-Android9-"$BUILD_NUMBER"

# check pass argument
while getopts "ourvn:" arg
do
    case $arg in
        o)
            echo "will build ota package"
            BUILD_OTA=true
            ;;
        u)
            echo "will build update.img"
            BUILD_UPDATE_IMG=true
            ;;
        v)
#            BUILD_VERSION=$OPTARG
            ;;
        n)
            BUILD_NUMBER="$OPTARG"-"$(date  +%Y%m%d)"
            RELEASE_NAME=Tinker_Edge_R-Android9-V"$BUILD_NUMBER"
            ;;
	r)
            echo "will pack the release"
	    PACK_RELEASE=true
	    ;;
        ?)
            usage ;;
    esac
done

source build/envsetup.sh >/dev/null && setpaths
TARGET_PRODUCT=`get_build_var TARGET_PRODUCT`

#set jdk version
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
# source environment and chose target product
DEVICE=`get_build_var TARGET_PRODUCT`
BUILD_VARIANT=`get_build_var TARGET_BUILD_VARIANT`
UBOOT_DEFCONFIG=tinker_edge_r_defconfig
KERNEL_DEFCONFIG=tinker_edge_r_defconfig
KERNEL_DTS=`get_build_var TARGET_BUILD_DTB`
PACK_TOOL_DIR=RKTools/linux/Linux_Pack_Firmware
IMAGE_PATH=rockdev/Image-$TARGET_PRODUCT
export PROJECT_TOP=`gettop`

#lunch $DEVICE-$BUILD_VARIANT

#PLATFORM_VERSION=`get_build_var PLATFORM_VERSION`
#DATE=$(date  +%Y%m%d.%H%M)
STUB_PATH=IMAGE/"$RELEASE_NAME"
#STUB_PATH="$(echo $STUB_PATH | tr '[:lower:]' '[:upper:]')"
export STUB_PATH=$PROJECT_TOP/$STUB_PATH
export STUB_PATCH_PATH=$STUB_PATH/PATCHES

# build uboot
echo "start build uboot"
cd u-boot && make distclean && ./make.sh tinker_edge_r && cd -
if [ $? -eq 0 ]; then
    echo "Build uboot ok!"
else
    echo "Build uboot failed!"
    exit 1
fi


# build kernel
echo "Start build kernel"
cd kernel && make clean &&make ARCH=arm64 $KERNEL_DEFCONFIG && make ARCH=arm64 $KERNEL_DTS.img -j12 && cd -
if [ $? -eq 0 ]; then
    echo "Build kernel ok!"
else
    echo "Build kernel failed!"
    exit 1
fi


# build android
echo "start build android"
make installclean
make BUILD_NUMBER=$BUILD_NUMBER -j12
if [ $? -eq 0 ]; then
    echo "Build android ok!"
else
    echo "Build android failed!"
    exit 1
fi

# mkimage.sh
echo "make and copy android images"
./mkimage.sh
if [ $? -eq 0 ]; then
    echo "Make image ok!"
else
    echo "Make image failed!"
    exit 1
fi

if [ "$BUILD_OTA" = true ] ; then
    INTERNAL_OTA_PACKAGE_OBJ_TARGET=obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-*.zip
    INTERNAL_OTA_PACKAGE_TARGET=$TARGET_PRODUCT-ota-*.zip
    echo "generate ota package"
    make BUILD_NUMBER=$BUILD_NUMBER otapackage -j4
    ./mkimage.sh ota
    cp $OUT/$INTERNAL_OTA_PACKAGE_TARGET $IMAGE_PATH/
    cp $OUT/$INTERNAL_OTA_PACKAGE_OBJ_TARGET $IMAGE_PATH/
fi


mkdir -p $PACK_TOOL_DIR/rockdev/Image/
cp -f $IMAGE_PATH/* $PACK_TOOL_DIR/rockdev/Image/

echo "Make update.img"
cd $PACK_TOOL_DIR/rockdev && ./mkupdate.sh
if [ $? -eq 0 ]; then
    echo "Make update image ok!"
else
    echo "Make update image failed!"
    exit 1
fi
cd -

mv $PACK_TOOL_DIR/rockdev/update.img $IMAGE_PATH/
rm $PACK_TOOL_DIR/rockdev/Image -rf

mkdir -p $STUB_PATH

#Generate patches
.repo/repo/repo forall  -c "$PROJECT_TOP/device/rockchip/common/gen_patches_body.sh"

#.repo/repo/repo forall  -c '[ "$REPO_REMOTE" = "rk" ] && { REMOTE_DIFF=`git log $REPO_REMOTE/$REPO_RREV..HEAD`; LOCAL_DIFF=`git diff`; [ -n "$REMOTE_DIFF" ] && { mkdir -p $STUB_PATCH_PATH/$REPO_PATH/; git format-patch $REPO_REMOTE/$REPO_RREV..HEAD -o $STUB_PATCH_PATH/$REPO_PATH; git merge-base HEAD $REPO_REMOTE/$REPO_RREV | xargs git show -s > $STUB_PATCH_PATH/$REPO_PATH/git-merge-base.txt; } || :; [ -n "$LOCAL_DIFF" ] && { mkdir -p $STUB_PATCH_PATH/$REPO_PATH/; git reset HEAD ./; git diff > $STUB_PATCH_PATH/$REPO_PATH/local_diff.patch; } || :; }'

#Copy stubs
cp commit_id.xml $STUB_PATH/manifest_$RELEASE_NAME.xml

mkdir -p $STUB_PATCH_PATH/kernel
cp kernel/.config $STUB_PATCH_PATH/kernel
cp kernel/vmlinux $STUB_PATCH_PATH/kernel

mkdir -p $STUB_PATH/IMAGES/
cp $IMAGE_PATH/* $STUB_PATH/IMAGES/
cp build.sh $STUB_PATH/build.sh
#Save build command info
echo "UBOOT:  defconfig: $UBOOT_DEFCONFIG" >> $STUB_PATH/build_cmd_info
echo "KERNEL: defconfig: $KERNEL_DEFCONFIG, dts: $KERNEL_DTS" >> $STUB_PATH/build_cmd_info
echo "ANDROID:$DEVICE-$BUILD_VARIANT" >> $STUB_PATH/build_cmd_info

if [ "$PACK_RELEASE" = true ] ; then
	mkdir -p $STUB_PATH/$RELEASE_NAME
	mv $STUB_PATH/IMAGES/update.img $STUB_PATH/$RELEASE_NAME/.
	cp -rp $PROJECT_TOP/device/asus/tinker_edge_r/flash/. $STUB_PATH/$RELEASE_NAME
	cd $STUB_PATH
	zip -r $RELEASE_NAME.zip $RELEASE_NAME
	sha256sum $RELEASE_NAME.zip > $RELEASE_NAME.zip.sha256sum
	cd -
	rm -rf $STUB_PATH/$RELEASE_NAME
fi
