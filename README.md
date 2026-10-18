# NetTre（ネトレ）

CCNA などネットワーク資格向けの、iPhone で片手で使える問題演習アプリ。

## フォルダ構成

```
NetTre/
├── CLAUDE.md      # プロジェクトの方針・現状・TODO
├── NetTre/        # アプリ本体（Models, Generators, Resources …）
├── NetTreTests/   # Swift Testing のテスト
├── docs/          # 要件定義書・基本設計書・画面仕様書 ほか
└── handoff/       # 引き継ぎ時の zip（記録として保管）
```

Xcode プロジェクトは XcodeGen の `project.yml` から生成する予定（`.xcodeproj` は Git で管理しない）。
