# 1
# Set bash script to exit immediately if any commands fail.
set -e


# 2
# Setup some constants for use later on.
PRODUCT=PlivoVoiceKit

RELEASE_UNIVERSAL_DIR=output
DEVICE_DIR=device
SIMULATOR_DIR=simulator
# 3
# If remnants from a previous build exist, delete them.

if [ -d "${RELEASE_UNIVERSAL_DIR}" ]; then
rm -rf "${RELEASE_UNIVERSAL_DIR}"
fi

if [ -d "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}" ]; then
rm -rf "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}"
fi

if [ -d "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}" ]; then
rm -rf "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}"
fi

mkdir "${RELEASE_UNIVERSAL_DIR}"
mkdir "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}"
mkdir "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}"
#
## 4
##Build for all platforms/configurations.
xcodebuild archive BITCODE_GENERATION_MODE=bitcode -workspace "${PRODUCT}.xcworkspace" -scheme "${PRODUCT}" ONLY_ACTIVE_ARCH=NO -configuration Release -destination 'generic/platform=iOS' -archivePath "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}/${PRODUCT}.framework-iphoneos.xcarchive" SKIP_INSTALL=NO

xcodebuild archive BITCODE_GENERATION_MODE=bitcode -workspace "${PRODUCT}.xcworkspace" -scheme "${PRODUCT}" ONLY_ACTIVE_ARCH=NO -configuration Release -destination 'generic/platform=iOS Simulator' -archivePath "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}/${PRODUCT}.framework-iphonesimulator.xcarchive" SKIP_INSTALL=NO

xcodebuild -create-xcframework \
    -framework "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}/${PRODUCT}.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/${PRODUCT}.framework" \
    -framework "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}/${PRODUCT}.framework-iphoneos.xcarchive/Products/Library/Frameworks/${PRODUCT}.framework" \
    -output "${RELEASE_UNIVERSAL_DIR}"/${PRODUCT}.xcframework

## 5
##Copy dsym and build symbols
for sclice in "${RELEASE_UNIVERSAL_DIR}"/${PRODUCT}.xcframework/*/
do
  echo "$sclice"
    if [[ $sclice =~ "simulator" ]]; then
        cp -R "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}/${PRODUCT}.framework-iphonesimulator.xcarchive/dSYMs" "${sclice}/"
    else
        cp -R "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}/${PRODUCT}.framework-iphoneos.xcarchive/dSYMs" "${sclice}/"
        cp -R "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}/${PRODUCT}.framework-iphoneos.xcarchive/BCSymbolMaps" "${sclice}/"
    fi
done

# 6
# If remnants from a previous build exist, delete them.

if [ -d "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}" ]; then
rm -rf "${RELEASE_UNIVERSAL_DIR}/${DEVICE_DIR}"
fi

if [ -d "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}" ]; then
rm -rf "${RELEASE_UNIVERSAL_DIR}/${SIMULATOR_DIR}"
fi

