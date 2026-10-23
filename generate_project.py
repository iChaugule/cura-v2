#!/usr/bin/env python3
"""
generate_project.py
Generates a valid Xcode 15 project (Cura.xcodeproj/project.pbxproj) by
walking /Users/raj/Documents/cura/Cura/ recursively and collecting all
.swift, .xcassets, .plist, .strings, .stringsdict, and .xcstrings files.

Usage:
    python3 generate_project.py
"""

import os
import sys
import uuid
import json
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECT_ROOT   = Path("/Users/raj/Documents/cura")
SOURCE_ROOT    = PROJECT_ROOT / "Cura"
XCODEPROJ_DIR  = PROJECT_ROOT / "Cura.xcodeproj"
PBXPROJ_PATH   = XCODEPROJ_DIR / "project.pbxproj"

BUNDLE_ID      = "com.cura.app"
APP_NAME       = "Cura"
SWIFT_VERSION  = "5"
DEPLOYMENT_TARGET = "17.0"
OBJECT_VERSION = "56"

# ---------------------------------------------------------------------------
# GUID helpers
# ---------------------------------------------------------------------------

_used_guids: set[str] = set()

def new_guid() -> str:
    """Generate a unique 24-char uppercase hex GUID."""
    while True:
        g = uuid.uuid4().hex[:24].upper()
        if g not in _used_guids:
            _used_guids.add(g)
            return g

# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------

SOURCE_EXTENSIONS   = {".swift"}
RESOURCE_EXTENSIONS = {".xcassets", ".strings", ".stringsdict", ".xcstrings"}
PLIST_EXTENSIONS    = {".plist"}
STORYBOARD_EXTENSIONS = {".storyboard"}

def collect_files(root: Path) -> dict[str, list[Path]]:
    """Walk root and bucket files by type."""
    buckets: dict[str, list[Path]] = {
        "swift":      [],
        "resources":  [],
        "plists":     [],
        "storyboards": [],
    }

    if not root.exists():
        print(f"Warning: source root {root} does not exist.", file=sys.stderr)
        return buckets

    for dirpath, dirnames, filenames in os.walk(root):
        # Skip hidden dirs and Xcode's derived data
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d != "DerivedData"]
        for filename in filenames:
            if filename.startswith("."):
                continue
            path = Path(dirpath) / filename
            suffix = path.suffix.lower()
            if suffix in SOURCE_EXTENSIONS:
                buckets["swift"].append(path)
            elif suffix in RESOURCE_EXTENSIONS or (path.is_dir() and suffix in RESOURCE_EXTENSIONS):
                buckets["resources"].append(path)
            elif suffix in PLIST_EXTENSIONS:
                buckets["plists"].append(path)
            elif suffix in STORYBOARD_EXTENSIONS:
                buckets["storyboards"].append(path)

    # Also detect .xcassets directories (os.walk passes dirs separately)
    for dirpath, dirnames, filenames in os.walk(root):
        for d in dirnames:
            if d.endswith(".xcassets"):
                buckets["resources"].append(Path(dirpath) / d)

    # Deduplicate (xcassets dirs may appear twice)
    buckets["resources"] = list(dict.fromkeys(buckets["resources"]))
    buckets["swift"].sort()
    buckets["resources"].sort()
    buckets["plists"].sort()
    buckets["storyboards"].sort()

    return buckets

# ---------------------------------------------------------------------------
# Ensure required files exist
# ---------------------------------------------------------------------------

def ensure_info_plist() -> Path:
    plist_path = SOURCE_ROOT / "Info.plist"
    if plist_path.exists():
        return plist_path

    print(f"Creating missing Info.plist at {plist_path}")
    plist_path.parent.mkdir(parents=True, exist_ok=True)
    plist_path.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"'
        ' "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        "<plist version=\"1.0\">\n<dict>\n"
        "\t<key>CFBundleIdentifier</key>\n\t<string>com.cura.app</string>\n"
        "\t<key>CFBundleName</key>\n\t<string>Cura</string>\n"
        "\t<key>CFBundleShortVersionString</key>\n\t<string>1.0</string>\n"
        "\t<key>CFBundleVersion</key>\n\t<string>1</string>\n"
        "\t<key>LSRequiresIPhoneOS</key>\n\t<true/>\n"
        "\t<key>UILaunchStoryboardName</key>\n\t<string>LaunchScreen</string>\n"
        "</dict>\n</plist>\n"
    )
    return plist_path


def ensure_assets() -> Path:
    assets_path = SOURCE_ROOT / "Resources" / "Assets.xcassets"
    contents = assets_path / "Contents.json"
    if not contents.exists():
        print(f"Creating missing Assets.xcassets at {assets_path}")
        assets_path.mkdir(parents=True, exist_ok=True)
        contents.write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    return assets_path

# ---------------------------------------------------------------------------
# pbxproj builders
# ---------------------------------------------------------------------------

def rel(path: Path) -> str:
    """Path relative to PROJECT_ROOT."""
    return str(path.relative_to(PROJECT_ROOT))

def file_type(path: Path) -> str:
    suffix = path.suffix.lower()
    mapping = {
        ".swift":       "sourcecode.swift",
        ".plist":       "text.plist.xml",
        ".xcassets":    "folder.assetcatalog",
        ".strings":     "text.plist.strings",
        ".stringsdict": "text.plist.stringsdict",
        ".xcstrings":   "text.plist.xcstrings",
        ".storyboard":  "file.storyboard",
    }
    return mapping.get(suffix, "file")


def build_pbxproj(
    swift_files: list[Path],
    resource_files: list[Path],
    plist_files: list[Path],
    storyboard_files: list[Path],
) -> str:
    """Return the complete text of project.pbxproj."""

    # --- Assign GUIDs ---
    project_guid        = new_guid()
    target_guid         = new_guid()
    sources_phase_guid  = new_guid()
    resources_phase_guid = new_guid()
    frameworks_phase_guid = new_guid()
    config_list_project_guid = new_guid()
    config_list_target_guid  = new_guid()
    debug_config_project_guid   = new_guid()
    release_config_project_guid = new_guid()
    debug_config_target_guid    = new_guid()
    release_config_target_guid  = new_guid()
    products_group_guid = new_guid()
    main_group_guid     = new_guid()
    sources_group_guid  = new_guid()
    resources_group_guid = new_guid()
    product_ref_guid    = new_guid()

    # File references
    swift_file_refs:    list[tuple[str, Path]] = [(new_guid(), p) for p in swift_files]
    resource_file_refs: list[tuple[str, Path]] = [(new_guid(), p) for p in resource_files]
    plist_file_refs:    list[tuple[str, Path]] = [(new_guid(), p) for p in plist_files]
    storyboard_file_refs: list[tuple[str, Path]] = [(new_guid(), p) for p in storyboard_files]

    # Build file entries (Swift only goes in Sources; resources/storyboards in Resources)
    swift_build_files:     list[tuple[str, str]] = [(new_guid(), fref) for fref, _ in swift_file_refs]
    resource_build_files:  list[tuple[str, str]] = [(new_guid(), fref) for fref, _ in resource_file_refs]
    storyboard_build_files: list[tuple[str, str]] = [(new_guid(), fref) for fref, _ in storyboard_file_refs]

    lines: list[str] = []
    w = lines.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w(f"\tobjectVersion = {OBJECT_VERSION};")
    w("\tobjects = {")
    w("")

    # ---- PBXBuildFile ----
    w("/* Begin PBXBuildFile section */")
    for bf_guid, fr_guid in swift_build_files:
        # find path for comment
        path = next(p for g, p in swift_file_refs if g == fr_guid)
        w(f"\t\t{bf_guid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_guid} /* {path.name} */; }};")
    for bf_guid, fr_guid in resource_build_files:
        path = next(p for g, p in resource_file_refs if g == fr_guid)
        w(f"\t\t{bf_guid} /* {path.name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr_guid} /* {path.name} */; }};")
    for bf_guid, fr_guid in storyboard_build_files:
        path = next(p for g, p in storyboard_file_refs if g == fr_guid)
        w(f"\t\t{bf_guid} /* {path.name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr_guid} /* {path.name} */; }};")
    w("/* End PBXBuildFile section */")
    w("")

    # ---- PBXFileReference ----
    w("/* Begin PBXFileReference section */")
    for fr_guid, path in swift_file_refs:
        rp = rel(path)
        w(f"\t\t{fr_guid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type(path)}; path = \"{path.name}\"; name = \"{path.name}\"; sourceTree = \"<group>\"; }};")
    for fr_guid, path in resource_file_refs:
        ft = "folder.assetcatalog" if path.suffix == ".xcassets" else file_type(path)
        w(f"\t\t{fr_guid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = \"{path.name}\"; name = \"{path.name}\"; sourceTree = \"<group>\"; }};")
    for fr_guid, path in plist_file_refs:
        w(f"\t\t{fr_guid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"{path.name}\"; name = \"{path.name}\"; sourceTree = \"<group>\"; }};")
    for fr_guid, path in storyboard_file_refs:
        w(f"\t\t{fr_guid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = file.storyboard; path = \"{path.name}\"; name = \"{path.name}\"; sourceTree = \"<group>\"; }};")
    # Product
    w(f"\t\t{product_ref_guid} /* Cura.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Cura.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w("/* End PBXFileReference section */")
    w("")

    # ---- PBXGroup ----
    w("/* Begin PBXGroup section */")

    # Main group
    w(f"\t\t{main_group_guid} = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{sources_group_guid} /* Cura */,")
    w(f"\t\t\t\t{resources_group_guid} /* Resources */,")
    w(f"\t\t\t\t{products_group_guid} /* Products */,")
    w("\t\t\t);")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Products group
    w(f"\t\t{products_group_guid} /* Products */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f"\t\t\t\t{product_ref_guid} /* Cura.app */,")
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Sources group (Swift files)
    w(f"\t\t{sources_group_guid} /* Cura */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for fr_guid, path in swift_file_refs:
        w(f"\t\t\t\t{fr_guid} /* {path.name} */,")
    for fr_guid, path in plist_file_refs:
        w(f"\t\t\t\t{fr_guid} /* {path.name} */,")
    for fr_guid, path in storyboard_file_refs:
        w(f"\t\t\t\t{fr_guid} /* {path.name} */,")
    w("\t\t\t);")
    w("\t\t\tname = Cura;")
    w(f"\t\t\tpath = Cura;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    # Resources group
    w(f"\t\t{resources_group_guid} /* Resources */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for fr_guid, path in resource_file_refs:
        w(f"\t\t\t\t{fr_guid} /* {path.name} */,")
    w("\t\t\t);")
    w("\t\t\tname = Resources;")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

    w("/* End PBXGroup section */")
    w("")

    # ---- PBXNativeTarget ----
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{target_guid} /* Cura */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {config_list_target_guid} /* Build configuration list for PBXNativeTarget \"Cura\" */;")
    w("\t\t\tbuildPhases = (")
    w(f"\t\t\t\t{sources_phase_guid} /* Sources */,")
    w(f"\t\t\t\t{resources_phase_guid} /* Resources */,")
    w(f"\t\t\t\t{frameworks_phase_guid} /* Frameworks */,")
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = Cura;")
    w("\t\t\tpackageProductDependencies = (")
    w("\t\t\t);")
    w(f"\t\t\tproductName = Cura;")
    w(f"\t\t\tproductReference = {product_ref_guid} /* Cura.app */;")
    w("\t\t\tproductType = \"com.apple.product-type.application\";")
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    # ---- PBXProject ----
    w("/* Begin PBXProject section */")
    w(f"\t\t{project_guid} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w(f"\t\t\t\tLastUpgradeCheck = 1500;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{target_guid} = {{")
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {config_list_project_guid} /* Build configuration list for PBXProject \"Cura\" */;")
    w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w(f"\t\t\tmainGroup = {main_group_guid};")
    w(f"\t\t\tproductsGroup = {products_group_guid} /* Products */;")
    w(f"\t\t\tprojectDirPath = \"\";")
    w("\t\t\tprojectRoot = \"\";")
    w("\t\t\ttargets = (")
    w(f"\t\t\t\t{target_guid} /* Cura */,")
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")

    # ---- PBXResourcesBuildPhase ----
    w("/* Begin PBXResourcesBuildPhase section */")
    w(f"\t\t{resources_phase_guid} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for bf_guid, fr_guid in resource_build_files:
        path = next(p for g, p in resource_file_refs if g == fr_guid)
        w(f"\t\t\t\t{bf_guid} /* {path.name} in Resources */,")
    for bf_guid, fr_guid in storyboard_build_files:
        path = next(p for g, p in storyboard_file_refs if g == fr_guid)
        w(f"\t\t\t\t{bf_guid} /* {path.name} in Resources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")

    # ---- PBXSourcesBuildPhase ----
    w("/* Begin PBXSourcesBuildPhase section */")
    w(f"\t\t{sources_phase_guid} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for bf_guid, fr_guid in swift_build_files:
        path = next(p for g, p in swift_file_refs if g == fr_guid)
        w(f"\t\t\t\t{bf_guid} /* {path.name} in Sources */,")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")

    # ---- PBXFrameworksBuildPhase ----
    w("/* Begin PBXFrameworksBuildPhase section */")
    w(f"\t\t{frameworks_phase_guid} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")
    w("")

    # ---- XCBuildConfiguration ----
    # Shared build settings
    common_project_settings: dict[str, str] = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    }
    common_release_project_settings = {
        **{k: v for k, v in common_project_settings.items() if k not in ("MTL_ENABLE_DEBUG_INFO", "ONLY_ACTIVE_ARCH", "SWIFT_ACTIVE_COMPILATION_CONDITIONS")},
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    }

    # Target-specific settings
    info_plist_path = str(plist_files[0].relative_to(PROJECT_ROOT)) if plist_files else "Cura/Info.plist"
    common_target_settings: dict[str, str] = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_ASSET_PATHS": '"Cura/Preview Content"',
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f'"{info_plist_path}"',
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchStoryboardName": "LaunchScreen",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SDKROOT": "iphoneos",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": '"1,2"',
    }

    def write_build_config(guid: str, name: str, settings: dict[str, str]) -> None:
        w(f"\t\t{guid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        for key, val in sorted(settings.items()):
            w(f"\t\t\t\t{key} = {val};")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    w("/* Begin XCBuildConfiguration section */")

    # Project-level Debug
    write_build_config(debug_config_project_guid, "Debug", {
        **common_project_settings,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": '"DEBUG=1 $(inherited)"',
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    })

    # Project-level Release
    write_build_config(release_config_project_guid, "Release", {
        **common_release_project_settings,
        "GCC_OPTIMIZATION_LEVEL": "s",
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    })

    # Target-level Debug
    write_build_config(debug_config_target_guid, "Debug", {
        **common_target_settings,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    })

    # Target-level Release
    write_build_config(release_config_target_guid, "Release", {
        **common_target_settings,
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
        "SWIFT_COMPILATION_MODE": "wholemodule",
    })

    w("/* End XCBuildConfiguration section */")
    w("")

    # ---- XCConfigurationList ----
    w("/* Begin XCConfigurationList section */")
    w(f"\t\t{config_list_project_guid} /* Build configuration list for PBXProject \"Cura\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{debug_config_project_guid} /* Debug */,")
    w(f"\t\t\t\t{release_config_project_guid} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w(f"\t\t{config_list_target_guid} /* Build configuration list for PBXNativeTarget \"Cura\" */ = {{")
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f"\t\t\t\t{debug_config_target_guid} /* Debug */,")
    w(f"\t\t\t\t{release_config_target_guid} /* Release */,")
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("")

    # Close objects + project root
    w("\t};")  # end objects
    w(f"\trootObject = {project_guid} /* Project object */;")
    w("}")

    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("Cura Xcode Project Generator")
    print("=" * 50)

    # Ensure required resources exist
    ensure_info_plist()
    assets_path = ensure_assets()

    # Collect files
    buckets = collect_files(SOURCE_ROOT)
    swift_files     = buckets["swift"]
    resource_files  = buckets["resources"]
    plist_files     = buckets["plists"]
    storyboard_files = buckets["storyboards"]

    # Ensure Info.plist is in plists list
    info_plist = SOURCE_ROOT / "Info.plist"
    if info_plist.exists() and info_plist not in plist_files:
        plist_files.insert(0, info_plist)

    print(f"\nSwift source files found ({len(swift_files)}):")
    for f in swift_files:
        print(f"  {f.relative_to(PROJECT_ROOT)}")

    print(f"\nResource files found ({len(resource_files)}):")
    for f in resource_files:
        print(f"  {f.relative_to(PROJECT_ROOT)}")

    print(f"\nProperty list files found ({len(plist_files)}):")
    for f in plist_files:
        print(f"  {f.relative_to(PROJECT_ROOT)}")

    print(f"\nStoryboard files found ({len(storyboard_files)}):")
    for f in storyboard_files:
        print(f"  {f.relative_to(PROJECT_ROOT)}")

    if not swift_files:
        print("\nWarning: no Swift files found. The project will have an empty Sources build phase.", file=sys.stderr)

    # Create xcodeproj directory
    XCODEPROJ_DIR.mkdir(parents=True, exist_ok=True)

    # Generate and write pbxproj
    pbxproj_content = build_pbxproj(swift_files, resource_files, plist_files, storyboard_files)
    PBXPROJ_PATH.write_text(pbxproj_content, encoding="utf-8")

    print(f"\nXcode project written to:")
    print(f"  {PBXPROJ_PATH}")
    print(f"\nTotal files included:")
    print(f"  Swift:       {len(swift_files)}")
    print(f"  Resources:   {len(resource_files)}")
    print(f"  Plists:      {len(plist_files)}")
    print(f"  Storyboards: {len(storyboard_files)}")
    print(f"\nBuild settings:")
    print(f"  Bundle ID:          {BUNDLE_ID}")
    print(f"  Swift version:      {SWIFT_VERSION}")
    print(f"  Deployment target:  iOS {DEPLOYMENT_TARGET}")
    print(f"  Strict concurrency: complete")
    print("\nDone. Open Cura.xcodeproj in Xcode 15 or later.")


if __name__ == "__main__":
    main()
