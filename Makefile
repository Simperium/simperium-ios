# See:
#
# - https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
# - https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages

LIB_NAME := Simperium
BUILD_DIR := .build/xcarchives
FRAMEWORK_NAME := $(LIB_NAME).framework
XCFRAMEWORKS_DIR := .build/xcframeworks
CODE_SIGNING_IDENTITY ?= "Apple Distribution: Automattic, Inc. (PZYM8XX95Q)"

IOS_SCHEME := $(LIB_NAME)
MACOS_SCHEME := $(LIB_NAME)-OSX

.PHONY: all clean
all: create_xcframework

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(XCFRAMEWORKS_DIR)

archive_simulator:
	xcodebuild archive \
		-scheme "Simperium iOS" \
		-destination "generic/platform=iOS Simulator" \
		-archivePath $(BUILD_DIR)/simulator.xcarchive \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

archive_ios:
	xcodebuild archive \
		-scheme "Simperium iOS" \
		-destination "generic/platform=iOS" \
		-archivePath $(BUILD_DIR)/ios.xcarchive \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

archive_macos:
	xcodebuild archive \
		-scheme "Simperium OSX" \
		-destination "generic/platform=macOS" \
		-archivePath $(BUILD_DIR)/macos.xcarchive \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

archive_all: archive_simulator archive_ios archive_macos

$(XCFRAMEWORKS_DIR)/$(LIB_NAME).xcframework: archive_all
	@mkdir -p $(XCFRAMEWORKS_DIR)
	xcodebuild -create-xcframework \
		-framework $(BUILD_DIR)/ios.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-framework $(BUILD_DIR)/simulator.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-framework $(BUILD_DIR)/macos.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-output $@

$(XCFRAMEWORKS_DIR)/$(LIB_NAME).xcframework.zip: $(XCFRAMEWORKS_DIR)/$(LIB_NAME).xcframework
	@mkdir -p $(XCFRAMEWORKS_DIR)
	codesign --timestamp -s $(CODE_SIGNING_IDENTITY) $<
	ditto -c -k --keepParent $< $@
	@echo "Checksum for $(LIB_NAME).xcframework.zip:"
	@swift package compute-checksum $@

create_xcframework: clean $(XCFRAMEWORKS_DIR)/$(LIB_NAME).xcframework.zip
