#!/bin/bash

# Clean before building
rm -rf DerivedData 2>/dev/null
rm Cartfile.resolved 2>/dev/null
rm -rf Carthage 2>/dev/null
rm -rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/Log4swift 2>/dev/null

carthage update --platform mac
xcodebuild build -project Log4swiftTestApp.xcodeproj -scheme Log4swiftTestApp
