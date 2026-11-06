# アニメーション軽量化メモ

## 実施内容

### 1. インポート時のキーフレーム削減

`model/enemy/have_animation` 配下の **394個の `.glb.import`** を変更。

| 対象 | 設定 |
|---|---|
| Idle / Walk / Run / Gesture / Dance など | `animation/fps=12` |
| Attack / Skill / BeHit / Dead | `animation/fps=24` |
| 全アニメーション | `animation/trimming=true` |

- 12fps: 289ファイル
- 24fps: 105ファイル
- `animation/remove_immutable_tracks=true` は既存設定を維持

> 15fps→12fps の追加削減では、インポート後のサイズはほぼ変わりませんでした
> （4,251MB → 4,249MB）。GLB内のメッシュ・スキンが支配的なためです。

### 2. 戦闘で不要なアニメーションを読み込まない

`unit_base.gd` の `set_animation_model_paths()` で装飾用アニメーションを除外。

除外キーワード:

```text
dance / groove / gesture / boxing / practice
```

これにより、`Dance` 系の大きなGLBを Idle の候補として読み込むことを防止。

さらに `battle_scene.gd` で、戦闘中は戦闘に必要なアニメーションだけを渡す。

```text
idle / alert / attack / combo / skill / behit / dead / arise / running / runfast / walk
```

### 3. モデルキャッシュの上限

`unit_base.gd` に `MAX_CACHED_ANIMATION_MODELS = 6` を追加。

アニメーション切り替えのたびにフルモデルを保持し続けないよう、
古い非表示モデルを `queue_free()` する。

## 結果

### キーフレーム削減のみ

インポート済みアニメーション `.scn` の合計サイズ:

- 変更前: **4,828.5 MB**
- 15fps/30fps 変更後: **4,251.0 MB**
- 12fps/24fps 変更後: **4,248.8 MB**

キーフレーム削減だけでは約12%で頭打ち。各アニメーションGLBが
キャラクターのメッシュ・スキン・テクスチャ参照を丸ごと含んでいるため。

### 1モデル + AnimationLibrary 化

21キャラクターについて、20個前後のアニメーションGLBから
`Animation` リソースだけを抽出し、`animations.tres` に統合。

- ライブラリ数: **21**
- 収録アニメーション数: **301**
- ライブラリ合計サイズ: **15.4 MB**

実行時は各ユニットが

```text
1つのベースモデル（Idle / Alert）
+ 共有 AnimationLibrary
```

だけを保持する。`AnimationPlayer.play("battle/Animation_...")` で再生するため、
アニメーション切り替え時のフルモデル複製がなくなった。

確認結果:

- `animation_library_loaded = true`
- 1ユニットあたり `loaded_models = 1`
- 被弾時に `battle/Animation_BeHit_FlyUp_withSkin` を再生
- フィールド敵・戦闘味方・戦闘敵のすべてでライブラリ再生を確認

### 元アニメーションGLBの退避

ライブラリ生成後、各キャラのベースモデル以外のアニメーションGLBを
プロジェクト外へ退避。

- 退避先: `D:\roguelikepuzzle2_animation_source_backup`（プロジェクト外）
- 退避量: **約8,176 MB**（アニメーションGLB + 不要PNGテクスチャ）
- プロジェクト内に残るアニメーション関連データ: **約535 MB**

`.godot/imported` の不要になったアニメーションキャッシュも削除し、
インポートキャッシュ全体は約 **1.0 GB**、プロジェクトフォルダ全体は約 **2.3 GB**
まで減少（変更前はアニメーション関連だけで約8GB）。

## 再生成する場合

1. `D:\roguelikepuzzle2_animation_source_backup` から元のアニメーションGLBと `.import` を戻す
2. `build_animation_libraries.gd.disabled` を `.gd` に戻す
3. 以下を実行

```powershell
godot --headless --path reference/godot4-procedurally-generated-terrain --script res://build_animation_libraries.gd
```

## 次の軽量化候補

1. 画面外・遠距離ユニットの `AnimationPlayer` 更新を停止する
2. 戦闘で使うアニメーションを Idle / Attack / Hit / Dead の4種に限定する
3. ベースモデル以外のテクスチャ・未使用モデルを整理する

## 追加: 初回攻撃・被弾時のフリーズ対策

原因は、`UnitBase.play_unit_animation()` が未ロードのアニメーションGLBを
`load()` で同期読み込みしていたこと。8〜20MB級のGLBを戦闘中に同期ロードすると
フレームが停止する。

対策:

- 戦闘開始時に Idle / Alert / Attack / Skill / BeHit / Dead / Running を
  `ResourceLoader.load_threaded_request()` で非同期先読み
- 戦闘中に未ロードのアニメーションを要求された場合は同期 `load()` を使わず、
  非同期ロードを開始して現在のモデルを表示したままにする
- 読み込み完了前に現在のモデルを非表示にしないよう、表示モデルの確定後に
  旧モデルを非表示化
- 初期表示モデルは Idle / Alert を優先し、`loaded_models` に登録して
  同じモデルの二重ロードを防止
- それでも間に合わない初回被弾は、ダメージポップアップと既存モーションで
  処理し、次回以降の被弾からアニメーションを再生
