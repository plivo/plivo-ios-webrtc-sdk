#!/bin/bash

# Define the name of the Pod framework to remove
POD_FRAMEWORK_NAME="Pods_PlivoVoiceKit.framework"
POD_TEST_FRAMEWORK_NAME="Pods_PlivoVoiceKitTests.framework"


# Remove the framework from the "Link Binary With Libraries" section in Xcode
xcodeproj_path=$(find . -name "*.xcodeproj")
pbxproj_path="/Users/runner/work/plivo-ios-sdk-webrtc/plivo-ios-sdk-webrtc/PlivoVoiceKit.xcodeproj/project.pbxproj"

echo $pbxproj_path
sed -i '' "s/.*$POD_FRAMEWORK_NAME.*//g" "$pbxproj_path"
sed -i '' "s/.*$POD_TEST_FRAMEWORK_NAME.*//g" "$pbxproj_path"
