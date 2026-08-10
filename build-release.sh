#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SUPPORTED_ABIS=("armeabi-v7a" "arm64-v8a")

# Java: prefer JAVA_HOME, otherwise fall back to common JDK 17 locations.
if [ -z "${JAVA_HOME:-}" ]; then
  for candidate in "/usr/lib/jvm/java-17-openjdk" "/usr/lib/jvm/java-17" "/usr/lib/jvm/jdk-17" "/opt/android-studio/jbr"; do
    if [ -x "$candidate/bin/java" ]; then
      JAVA_HOME="$candidate"
      break
    fi
  done
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
  echo "ERROR: JAVA_HOME is not set and no JDK 17 was found under /usr/lib/jvm or /opt/android-studio/jbr."
  echo "       Install JDK 17 or run: JAVA_HOME=/path/to/jdk17 ./build-release.sh"
  exit 1
fi
export JAVA_HOME

# Android SDK: prefer ANDROID_HOME, otherwise fall back to the default location.
if [ -z "${ANDROID_HOME:-}" ]; then
  if [ -d "$HOME/Android/Sdk" ]; then
    ANDROID_HOME="$HOME/Android/Sdk"
  else
    echo "ERROR: ANDROID_HOME is not set and no SDK was found under $HOME/Android/Sdk."
    echo "       Install the Android SDK or run: ANDROID_HOME=/path/to/sdk ./build-release.sh"
    exit 1
  fi
fi
if [ ! -d "$ANDROID_HOME/platforms" ]; then
  echo "ERROR: ANDROID_HOME does not look like an Android SDK: $ANDROID_HOME"
  exit 1
fi
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

BUILD_ROOT="$HOME/.gradle/bilitv-native-build"
SOURCE_APK="$BUILD_ROOT/app/outputs/apk/release/app-release.apk"
OUTPUT_DIR="$BUILD_ROOT/release-apks"
mkdir -p "$OUTPUT_DIR"

echo "Building BiliTVNative release APKs..."
echo "Java home:    $JAVA_HOME"
echo "Android SDK:  $ANDROID_HOME"
echo "Output dir:   $OUTPUT_DIR"
echo

build_abi() {
  local target_abi="$1"

  local supported=0
  for abi in "${SUPPORTED_ABIS[@]}"; do
    if [ "$abi" = "$target_abi" ]; then supported=1; break; fi
  done
  if [ "$supported" -ne 1 ]; then
    echo "Unsupported release ABI: $target_abi"
    echo "Supported values: ${SUPPORTED_ABIS[*]}"
    exit 1
  fi

  echo "Building target ABI: $target_abi"
  ./gradlew :app:assembleRelease -PtargetAbi="$target_abi"

  if [ ! -f "$SOURCE_APK" ]; then
    echo "Release APK was not generated: $SOURCE_APK"
    exit 1
  fi

  local output_apk="$OUTPUT_DIR/BiliTVNative-$target_abi-release.apk"
  cp -f "$SOURCE_APK" "$output_apk"
  echo "Created: $output_apk"
  echo
}

if [ "$#" -eq 0 ]; then
  build_abi armeabi-v7a
  build_abi arm64-v8a
else
  build_abi "$1"
fi

echo "Release APKs are ready:"
for abi in "${SUPPORTED_ABIS[@]}"; do
  if [ -f "$OUTPUT_DIR/BiliTVNative-$abi-release.apk" ]; then
    echo "  $OUTPUT_DIR/BiliTVNative-$abi-release.apk"
  fi
done
