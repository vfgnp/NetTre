#!/bin/bash
# 06 IT-NF-02：権限・通信・外部パッケージ・プライバシーマニフェストを検査する（NFR-04・05・06）
# 使い方: scripts/check_nfr.sh [ビルドした .app のパス]
set -u
cd "$(dirname "$0")/.."
fail=0

app="${1:-}"
if [ -n "$app" ]; then
  if plutil -p "$app/Info.plist" | grep -q 'UsageDescription'; then
    echo "NG: Info.plist に NS*UsageDescription がある"; fail=1
  else
    echo "OK: 権限の説明文（NS*UsageDescription）なし"
  fi
  [ -f "$app/PrivacyInfo.xcprivacy" ] && echo "OK: PrivacyInfo.xcprivacy がアプリに入っている" \
    || { echo "NG: PrivacyInfo.xcprivacy がアプリにない"; fail=1; }
fi

if grep -rnE 'URLSession|import Network\b|NWConnection' NetTre --include=*.swift; then
  echo "NG: 通信の API を使っている"; fail=1
else
  echo "OK: URLSession・Network フレームワークを使っていない"
fi

if find . -name Package.resolved -not -path './build/*' | grep -q .; then
  echo "NG: Package.resolved がある（外部パッケージ）"; fail=1
else
  echo "OK: 外部パッケージなし"
fi

[ -f NetTre/Resources/PrivacyInfo.xcprivacy ] && echo "OK: PrivacyInfo.xcprivacy がある" \
  || { echo "NG: PrivacyInfo.xcprivacy がない"; fail=1; }

exit $fail
