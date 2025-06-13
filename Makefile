LIB_NAME := Simperium
BUILD_DIR := .build/xcarchives
FRAMEWORK_NAME := $(LIB_NAME).framework
XCFRAMEWORKS_DIR := .build/xcframeworks

IOS_SCHEME := $(LIB_NAME)
MACOS_SCHEME := $(LIB_NAME)-OSX

define BUILD_XCFRAMEWORK
build_xcframework_$(1): $(XCFRAMEWORKS_DIR)/$(LIB_NAME)-$(1).xcframework.zip

$(BUILD_DIR)/simulator.xcarchive:
	xcodebuild archive \
		-scheme "Simperium iOS" \
		-destination "generic/platform=iOS Simulator" \
		-archivePath $$@ \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

$(BUILD_DIR)/$(1).xcarchive:
	xcodebuild archive \
		-scheme "Simperium $(if $(filter ios,$(1)),iOS,OSX)" \
		-destination "generic/platform=$(if $(filter ios,$(1)),iOS,macOS)" \
		-archivePath $$@ \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

$(BUILD_DIR)/ios_all.xcarchive: $(BUILD_DIR)/ios.xcarchive $(BUILD_DIR)/simulator.xcarchive
	@touch $$@

$(XCFRAMEWORKS_DIR)/$(LIB_NAME)-$(1).xcframework: $(BUILD_DIR)/$(1).xcarchive
	@mkdir -p $(XCFRAMEWORKS_DIR)
	xcodebuild -create-xcframework \
		-framework $(BUILD_DIR)/$(1).xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-output $$@

$(XCFRAMEWORKS_DIR)/$(LIB_NAME)-ios.xcframework: $(BUILD_DIR)/ios_all.xcarchive
	@mkdir -p $(XCFRAMEWORKS_DIR)
	xcodebuild -create-xcframework \
		-framework $(BUILD_DIR)/ios.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-framework $(BUILD_DIR)/simulator.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-output $$@

$(XCFRAMEWORKS_DIR)/$(LIB_NAME)-macos.xcframework: $(BUILD_DIR)/macos.xcarchive
	@mkdir -p $(XCFRAMEWORKS_DIR)
	xcodebuild -create-xcframework \
		-framework $(BUILD_DIR)/macos.xcarchive/Products/Library/Frameworks/$(FRAMEWORK_NAME) \
		-output $$@

$(XCFRAMEWORKS_DIR)/$(LIB_NAME)-$(1).xcframework.zip: $(XCFRAMEWORKS_DIR)/$(LIB_NAME)-$(1).xcframework
	@mkdir -p $(XCFRAMEWORKS_DIR)
	zip -r $$@ $$<
endef

$(eval $(call BUILD_XCFRAMEWORK,ios))
$(eval $(call BUILD_XCFRAMEWORK,macos))

build_all: build_xcframework_ios build_xcframework_macos
