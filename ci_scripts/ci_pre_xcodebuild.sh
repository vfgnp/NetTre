#!/bin/sh
#
# 汎用テンプレート — 新しいプロジェクトの `ci_scripts/ci_pre_xcodebuild.sh` として
# コピーして使う(リポジトリ直下 or .xcodeproj と同じ階層に `ci_scripts/` を置く)。
#
# 目的: ビルド番号を Xcode Cloud の CI_BUILD_NUMBER(ワークフロー単調増加)に自動設定。
#   → 手動バンプ不要、"Preparing build for App Store Connect failed"(番号重複)を恒久回避。
#
# 方式: リポジトリ内の *.xcodeproj/project.pbxproj の CURRENT_PROJECT_VERSION を書き換える。
#   Info.plist が CFBundleVersion=$(CURRENT_PROJECT_VERSION) を参照する標準構成で動く
#   (XcodeGen 既定を含む)。Info.plist に数値を直書きしている場合は下の PLIST 方式に切替。
#
set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "ci_pre_xcodebuild: CI_BUILD_NUMBER 未設定 → スキップ(ローカル実行)"
  exit 0
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"

PBXPROJ=$(ls -d ./*.xcodeproj/project.pbxproj 2>/dev/null | head -1)
if [ -z "$PBXPROJ" ]; then
  echo "ci_pre_xcodebuild: *.xcodeproj/project.pbxproj が見つからない" >&2
  exit 1
fi

/usr/bin/sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "$PBXPROJ"
echo "ci_pre_xcodebuild: CURRENT_PROJECT_VERSION=${CI_BUILD_NUMBER} を設定 ($PBXPROJ)"

# --- 代替: Info.plist に CFBundleVersion を直書きする構成の場合はこちら ---
# PLIST="$CI_PRIMARY_REPOSITORY_PATH/<App>/Resources/Info.plist"
# /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$PLIST"
