![Plivo](https://s3.amazonaws.com/plivo_blog_uploads/logo/Plivo-logo.svg?v=202108181547) 

[![Swift](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.1_5.2_5.3_5.4-Orange?style=flat-square)
[![Platforms](https://img.shields.io/badge/Platforms-macOS_iOS-yellowgreen?style=flat-square)](https://img.shields.io/badge/Platforms-macOS_iOS_tvOS_watchOS_Linux_Windows-Green?style=flat-square)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Alamofire.svg?style=flat-square)](https://img.shields.io/cocoapods/v/Alamofire.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat-square)](https://github.com/Carthage/Carthage)
![CocoaPods compatible](https://img.shields.io/badge/CocoaPods-compatible-green.svg)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

# PlivoVoiceKit 

The Plivo iOS SDK v3 allows you to make outgoing and receive incoming calls in your iOS application. It's bitcode enabled and supports Pushkit and Callkit, hence eliminating the need for persistent connections to receive incoming calls. The SDK currently supports iOS versions 10 and above, including iOS 12. It supports both IPv4, IPv6 networks for performing inbound and outbound calls..

## Requirements

| Platform | Minimum Swift Version | Installation | Status |
| --- | --- | --- | --- |
| iOS 10.0+ / macOS 10.14+ | 5.1 | [CocoaPods](#cocoapods), [Swift Package Manager](#swift-package-manager) | Fully Tested |

## Installation

* Installation of **[Git Large File Storage](https://git-lfs.github.com)**

> **IMPORTANT**: **MAKE sure to install Git LFS before installing the pod**. The size of `WebRTC.xcframework` in **PlivoWebRTC** folder must be over 600 MB. If the size of the loaded `PlivoWebRTC` framework is smaller than 600 MB, check the **Git Large File Storage** settings and download again.

## SDK dependencies

### WebRTC

* [WebRTC framework](https://github.com/plivo/plivo-webrtc-ios.git), which can be integrated by `CocoaPods`, `SPM`, or manual set-up.

### OpenSSL 

To build openSSL with bitcode enable follow the given repo : https://github.com/openssl/openssl

## Getting started

This section gives you information you need to get started with PlivoVoiceKit SDK for iOS.

### Install Calls SDK

To use PlivoVoiceKit Calls, first add our custom-built `WebRTC` framework to the project. [Git Large File Storage](https://git-lfs.github.com) must be installed to use the `WebRTC ` framework along with the `PlivoVoiceKit` framework.

- Run `brew install git-lfs` in the project directory. 

#### CocoaPods

Add below into your Podfile.

```
platform :ios, '12.0'
use_frameworks!

target PlivoVoiceKit do
  pod 'PlivoWebRTC'
end
```

Install WebRTC Framework through CocoaPods.

```
pod install
```

Now you can see installed PlivoVoiceKit framework by inspecting `YOUR_PROJECT.xcworkspace`.

#### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but PlivoVoiceKit does support its use on supported platforms.

Once you have your Swift package set up, adding PlivoVoiceKit as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/plivo/plivo-webrtc-ios.git", .upToNextMajor(from: "1.0.))
]
```

#### Building the XCFramework:

Once the individual archives have been compiled, we can create the XCFramework itself.

```swift
./build.sh
 ```
  
#### Publicly host the XCFramework

In order to distribute the compiled package, we need to host it somewhere with public accessibility. One way to do this is to push the XCFramework to the S3 bucket and use that as the binary target URL.

Going with this route, we need to create a ZIP file with the XCFramework at the root and calculate the checksum of the resulting file, which will be needed for the Package manifest.

```swift
# Create the ZIP file
zip -r -X PlivoVoiceKit.xcframework.zip PlivoVoiceKit.xcframework
```

```swift
# Calculate the checksum
swift package compute-checksum PlivoVoiceKit.xcframework.zip
```






## Build & Release Process for WebRTC xcframework

To cross compile latest webRTC framework follow the given steps :

1 : open terminal in your mac
2 : Clone the depot tools
```
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
```
Add the tools to the path
```
export PATH=$PATH:"`pwd`/depot_tools"
```
Download the WebRTC source code
```
mkdir webrtc_ios
```

```
cd webrtc_ios
```
This will take some time
```
fetch --nohooks webrtc_ios
```

```
gclient sync
```
Let's start building
```
cd src
```
Build the framework, remove --arch "arm64 x64" to build ALL architectures, including 32 bit
```
tools_webrtc/ios/build_ios_libs.py --bitcode --arch arm64 x64
```
The framework is at out_ios_libs/WebRTC.framework

3 : Create XCFramework using create XCFramework command 

  
#### Publicly host the XCFramework

In order to distribute the compiled package, we need to host it somewhere with public accessibility. One way to do this is to push the XCFramework to the S3 bucket and use that as the binary target URL.

Going with this route, we need to create a ZIP file with the XCFramework at the root and calculate the checksum of the resulting file, which will be needed for the Package manifest.

```swift
# Create the ZIP file
zip -r -X WebRTC.xcframework.zip WebRTC.xcframework
```

```swift
# Calculate the checksum
swift package compute-checksum WebRTC.xcframework.zip
```

#### Release

* Change version in PlivoWebRTC.podspec in develop branch and commit it.
* Create existing production master tag with the same version.
* Merge changes from develop to master and create a new tag.
* Release on cocoapods using these commands : 
```swift
  git tag '1.0.6'
  git push --tags
  pod cache clean --all
  pod trunk register {EMAIL} ‘{NAME}' --description='macbook air'
```
* Verify Email from cocoapods.
* Release on CocoaPods. 
```swift
 pod lib lint --verbose --allow-warnings --no-clean
 pod spec lint --verbose
 pod trunk push PlivoWebRTC.podspec --verbose
```

### Carthage

> Requires Carthage version 0.38 or higher

1. Add `binary "https://raw.githubusercontent.com/plivo/plivo-webrtc-ios/main/PlivoWebRTC.json"` to your Cartfile.
2. Run `carthage update --use-xcframeworks`.
3. Go to your Xcode project's `"General"` settings. Open `<YOUR_XCODE_PROJECT_DIRECTORY>/Carthage/Build/iOS` in Finder and drag `WebRTC.xcframework` to the `"Embedded Binaries"` section in Xcode. Make sure `Copy items if needed` is selected and click `Finish`.
