# 1
# Set bash script to exit immediately if any commands fail.
set -e

SCHEME=PlivoVoiceKitTests
PROJECT=PlivoVoiceKit

xcodebuild test -workspace "${PROJECT}.xcworkspace" -scheme "PlivoVoiceKitTests" -destination 'platform=iOS Simulator,name=iPhone 12'
