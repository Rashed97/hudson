# colorization fix in Jenkins
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""

export USE_CCACHE=1
export CCACHE_NLEVELS=4
export BUILD_WITH_COLORS=0

git config --global user.name $(whoami)@$NODE_NAME
git config --global user.email jenkins@androidarmv6.org

mkdir -p $REPO_BRANCH
cd $REPO_BRANCH

if [ "$BASE" = "aosp" ]
then
repo init -u https://android.googlesource.com/platform/manifest -b refs/tags/$REPO_BRANCH
else
repo init -u https://github.com/CyanogenMod/android.git -b $SYNC_BRANCH $MANIFEST
fi
check_result "repo init failed."

# make sure ccache is in PATH
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"
export CCACHE_DIR=~/.ccache

mkdir -p .repo/local_manifests

rm -rf $WORKSPACE/build_env
git clone https://github.com/Rashed97/cm_build_config.git $WORKSPACE/build_env -b master
check_result "Bootstrap failed"

if [ -f $WORKSPACE/build_env/bootstrap.sh ]
then
  bash $WORKSPACE/build_env/bootstrap.sh
fi

cp $WORKSPACE/build_env/$REPO_BRANCH.xml .repo/local_manifests/dyn-$REPO_BRANCH.xml

cd .repo/local_manifests
curl -O https://raw.githubusercontent.com/Rashed97/local_manifests/master/g2_staging-cm-12.0.xml
cd ../..

echo Syncing...
repo sync -d -c > /dev/null
check_result "repo sync failed."
echo Sync complete.

# Unpack vendor/cm
$WORKSPACE/hudson/cm-setup.sh

. build/envsetup.sh

# Set lunch
lunch $LUNCH

# Perform the build
schedtool -B -n 1 -e ionice -n 1 make -j$(cat /proc/cpuinfo | grep "^processor" | wc -l) "$@" otapackage
check_result "Build failed."

# Build is done, cleanup the environment
cleanup
