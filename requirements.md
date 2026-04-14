# 产品需求文档 (PRD): Phonetics Maestro V1.0

> 说明：本文件是产品目标与范围文档，不是当前实现状态的权威来源。当前仓库已实现的功能、运行入口和验证方式请优先查看 `docs/current-state.md`。

- **文档状态:** Draft → Review-Ready
- **目标平台:** macOS 14.0+ (Sonoma) Native
- **核心定位:** 专注于"听辨-输出-矫正"闭环的本地化外语发音刻意练习工具。

---

## 1. 产品概述 (Product Overview)

### 1.1 背景与痛点

二语习得中的发音问题，很大程度上来源于母语负迁移导致的"音素耳盲"（即大脑无法感知特定音素的声学边界）。市面上的语言学习 App 往往侧重于词汇和语法，缺乏针对发音细节（如相似音素对比、元音开口度、句子连读）的深度、高频"刻意练习"工具。

### 1.2 产品愿景

打造一款极简、无干扰的 macOS 桌面应用，通过最小对立体 (Minimal Pairs) 的高频对比训练，结合本地极速的录音回放，帮助用户建立精确的发音肌肉记忆。配合外部 Agentic CLI 工作流（V2），实现动态词库生成。

### 1.3 核心用户故事 (User Stories)

- **US-1 听辨:** 作为学习者，我希望先测试自己的耳朵能否分辨 bat 和 but，只有听对了，我才去练习发音，以免巩固错误的肌肉记忆。
- **US-2 录音对比:** 作为学习者，我希望一键录下自己的发音，并与标准音进行无缝的 A-B-A-B 循环比对，从而"听"出自己发音部位的微小偏差。
- **US-3 渐进难度:** 作为学习者，我希望从单个音素开始，逐步过渡到单词和句子，系统性地矫正发音。

---

## 2. 核心体验闭环 (The Core Loop)

本应用的核心交互必须严格遵循以下 SLA（二语习得）逻辑递进：

1. **感知 (Perception - 听辨):** 盲听目标音，强迫大脑建立声学分类边界。
2. **输出 (Production - 发声):** 基于建立的听觉认知，调动口腔肌肉发声并录音。
3. **矫正 (Correction - 回放对比):** 利用骨传导与空气传导的差异，通过 ABAB 循环播放，进行客观的自我审视与纠偏。

---

## 3. 功能需求说明 (Functional Requirements)

### 3.1 训练层级划分 (Training Tiers)

| Tier | 名称 | 侧重点 | 音频源策略 |
|------|------|--------|-----------|
| 1 | 音素 (Phonemes) | 元音/辅音的发音部位（如 /ʌ/ vs /æ/） | **macOS TTS** (Siri Voice) |
| 2 | 单词 (Words) | 拼读规则与词内重音（如 effect vs affect） | **macOS TTS** (Siri Voice) |
| 3 | 句子 (Sentences) | 连读、失去爆破、弱读与语调 | **macOS TTS** (Siri Voice) |

> **音频源决策（已验证）：** V1 统一使用 macOS 原生 TTS (`com.apple.voice.premium.en-US.Ava` 或同等高品质 Siri Voice) 作为标准音。经手动测试，TTS 在 minimal pair 层面的区分度满足训练需求。优势：零延迟、零 API 成本、完全离线。
>
> **未来扩展点（V2）：** 如需更高保真度的音素级标准音，可引入 Wikipedia IPA chart 公开音频文件作为 Tier 1 的可选替代源。届时需在 `AudioService` 中增加文件播放通道。

### 3.2 核心训练卡片页 (The Training Card — P0)

对应 UI 设计图二。

#### 3.2.1 目标展示区 (Target Display)

- 展示对比的 **Left Target (A)** 和 **Right Target (B)**（例如 `but` vs `bat`）。
- 包含对应的 IPA 音标显示（如 `/bʌt/` vs `/bæt/`）。
- 当 Tier = Phonemes 时，仅显示音素符号（如 `/ʌ/` vs `/æ/`）。

#### 3.2.2 听辨模块 (Perception Module)

- **Random Test:** 点击后，系统随机（50/50 概率）播放 A 或 B 的标准音。
- **用户判断:** 用户点击下方按钮选择听到的词。
- **即时反馈:** 选对亮绿，选错亮红并播放正确发音，计入当前 Session 统计。

#### 3.2.3 练习模块 (Production Module)

- **录音交互:** 点击 Record 按钮开始录音，再次点击结束（**Toggle 模式**，非 press-and-hold）。录音时按钮显示红色脉冲动画。
- **单轨回放:** 提供 `Me`（我的录音）和 `Standard`（标准音）单独播放按钮。
- **ABAB 循环播放（核心功能）：** 点击 `A/B` 按钮进入循环模式，交替播放 `[标准音 → 300ms静默 → 我的录音 → 300ms静默]`，循环直到用户点击停止。提供播放速度控制（0.75x / 1.0x / 1.25x）。

> **技术约束：** 标准音和录音长度不同，两段之间插入固定 300ms 静默间隔，让大脑有切换时间。不做 time-stretching。

#### 3.2.4 状态打标 (Tagging)

- 提供 `★ Save`（收藏）和 `! Hard`（困难）按钮。
- 打标数据存入本地 SQLite，关联当前 pair/sentence ID。

#### 3.2.5 会话统计 (Session Stats)

实时显示（底部状态栏）：

| 指标 | 说明 |
|------|------|
| LISTENS | 听辨模块播放次数 |
| CORRECT | 听辨正确率（正确数/总数） |
| PRACTICES | 录音次数 |
| TIME | 当前卡片停留时间 (mm:ss) |

#### 3.2.6 卡片导航

- `Next Card →` 按钮跳转至当前组的下一对 minimal pair。
- 支持键盘快捷键：`←/→` 切换卡片，`Space` 播放 Random Test，`R` 开始/停止录音。

### 3.3 欢迎页 (Welcome Page — P0)

对应 UI 设计图一。

- **Begin:** 进入训练模式，从上次未完成的 session 或新 session 开始。
- **History:** 查看历史 session 的统计汇总（日期、练习时长、正确率趋势）。
- **Settings:** TTS 语音选择、麦克风选择、ABAB 间隔时长调整。

### 3.4 侧边栏导航 (Sidebar — P0)

- 始终显示 Begin / History / Settings 三个入口。
- 训练时高亮 Begin，显示当前训练的 Tier 和音素对标签。
- **可折叠：** 用户可通过点击或快捷键 `⌘+\` 折叠侧边栏以最大化训练区域。

### 3.5 外部数据管线与 CLI (Data Pipeline — V2，本版不实现)

> **V1 范围排除：** 以下功能在 V1 中 **不实现**，仅在架构层面预留扩展接口。

- CLI 工具：允许用户通过命令调用 LLM API，生成特定规则的数据并写入 SQLite。
- 预留 `DataImportService` protocol，V1 仅实现 `SeedDataImporter`（从 Bundle JSON 导入种子数据）。

### 3.6 种子数据规格 (Seed Data Specification — P0)

V1 必须内置以下种子数据，随 App Bundle 分发：

#### 中国人英语核心易混音素对（12 对）

| # | 音素 A | 音素 B | 示例 Minimal Pairs (每对至少 5 组) |
|---|--------|--------|-----------------------------------|
| 1 | /ʌ/ | /æ/ | but/bat, cut/cat, hut/hat, luck/lack, mud/mad |
| 2 | /ɪ/ | /iː/ | bit/beat, fit/feet, hit/heat, sit/seat, ship/sheep |
| 3 | /e/ | /æ/ | bet/bat, set/sat, pen/pan, met/mat, head/had |
| 4 | /ɒ/ (或 /ɑː/) | /ʌ/ | cop/cup, hot/hut, shot/shut, lock/luck, not/nut |
| 5 | /ʊ/ | /uː/ | pull/pool, full/fool, look/Luke, should/shoed, could/cooed |
| 6 | /l/ | /r/ | light/right, lead/read, long/wrong, fly/fry, glass/grass |
| 7 | /θ/ | /s/ | think/sink, thick/sick, math/mass, path/pass, thought/sort |
| 8 | /ð/ | /z/ | then/zen, breathe/breeze, bathe/bays, clothe/close, teethe/tease |
| 9 | /n/ | /ŋ/ | sin/sing, ban/bang, thin/thing, win/wing, run/rung |
| 10 | /v/ | /w/ | vine/wine, vet/wet, vest/west, veil/wail, vow/wow |
| 11 | /ɜː/ | /ɑː/ | bird/bard, fur/far, her/ha, stir/star, fern/barn |
| 12 | /æ/ | /eɪ/ | man/main, pan/pain, ran/rain, plan/plain, bad/bade |

#### 句子层种子数据（至少 10 句）

覆盖以下连读/弱读现象，每种至少 2 句：

- 辅音-元音连读 (Linking): e.g. "pick‿it‿up"
- 失去爆破 (Elision): e.g. "last time"
- 弱读 (Reduction): e.g. "cup of tea" → /kʌpətiː/
- 语调对比 (Intonation): 陈述句 vs 疑问句同一句子
- 重音转移 (Stress Shift): e.g. "record" (n.) vs "record" (v.)

> **数据格式：** 种子数据以 JSON 文件存储于 App Bundle 的 `Resources/SeedData/` 目录，App 首次启动时通过 `SeedDataImporter` 写入 SQLite。JSON schema 见 ARCHITECTURE.md §4。

---

## 4. 数据结构 (Database Schema)

使用 SQLite 进行本地化存储。数据库文件位于 `~/Library/Application Support/PhoneticsMaestro/maestro.sqlite`。

### 4.1 表定义

```sql
-- 音素表
CREATE TABLE phonemes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol      TEXT NOT NULL UNIQUE,  -- IPA 符号，如 'ʌ'
    example     TEXT,                  -- 示例词，如 'cup'
    description TEXT,                  -- 发音描述
    audio_key   TEXT                   -- TTS 发音的参考文本
);

-- 单词表
CREATE TABLE words (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    text        TEXT NOT NULL,         -- 单词文本，如 'but'
    ipa         TEXT NOT NULL,         -- IPA 音标，如 '/bʌt/'
    phoneme_id  INTEGER REFERENCES phonemes(id),  -- 关联的核心音素
    tier        INTEGER NOT NULL DEFAULT 2,        -- 所属层级 (1=phoneme, 2=word)
    definition  TEXT                   -- 简要释义
);

-- 最小对立体表（核心训练表）
CREATE TABLE pairs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    word_a_id       INTEGER NOT NULL REFERENCES words(id),
    word_b_id       INTEGER NOT NULL REFERENCES words(id),
    phoneme_contrast TEXT NOT NULL,    -- 音素对标识，如 'ʌ-æ' (用于批量查询)
    tier            INTEGER NOT NULL DEFAULT 2,
    difficulty      INTEGER NOT NULL DEFAULT 1  -- 1=easy, 2=medium, 3=hard
);

-- 句子表
CREATE TABLE sentences (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    text        TEXT NOT NULL,
    ipa         TEXT,
    phenomenon  TEXT NOT NULL,         -- 考察现象: linking/elision/reduction/intonation/stress
    notes       TEXT,                  -- 重点标记说明
    tier        INTEGER NOT NULL DEFAULT 3
);

-- 用户统计表
CREATE TABLE user_progress (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    item_type       TEXT NOT NULL,     -- 'pair' 或 'sentence'
    item_id         INTEGER NOT NULL,  -- 对应 pairs.id 或 sentences.id
    session_date    TEXT NOT NULL,     -- ISO 8601 日期
    listen_count    INTEGER DEFAULT 0,
    correct_count   INTEGER DEFAULT 0,
    wrong_count     INTEGER DEFAULT 0,
    practice_count  INTEGER DEFAULT 0, -- 录音次数
    time_spent_sec  INTEGER DEFAULT 0,
    is_saved        INTEGER DEFAULT 0, -- ★ Save 标记
    is_hard         INTEGER DEFAULT 0, -- ! Hard 标记
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 索引
CREATE INDEX idx_pairs_contrast ON pairs(phoneme_contrast);
CREATE INDEX idx_progress_item ON user_progress(item_type, item_id);
CREATE INDEX idx_progress_date ON user_progress(session_date);
```

### 4.2 种子数据 JSON Schema

```json
{
  "phoneme_pairs": [
    {
      "contrast": "ʌ-æ",
      "phoneme_a": { "symbol": "ʌ", "example": "cup", "description": "Open-mid back unrounded vowel" },
      "phoneme_b": { "symbol": "æ", "example": "cat", "description": "Near-open front unrounded vowel" },
      "pairs": [
        { "word_a": "but", "ipa_a": "/bʌt/", "word_b": "bat", "ipa_b": "/bæt/", "difficulty": 1 },
        { "word_a": "cut", "ipa_a": "/kʌt/", "word_b": "cat", "ipa_b": "/kæt/", "difficulty": 1 }
      ]
    }
  ],
  "sentences": [
    {
      "text": "Pick it up.",
      "ipa": "/pɪk‿ɪt‿ʌp/",
      "phenomenon": "linking",
      "notes": "辅音-元音连读: k‿ɪ 和 t‿ʌ"
    }
  ]
}
```

---

## 5. 非功能需求 (Non-Functional Requirements)

### 5.1 技术栈

| 领域 | 选型 | 约束 |
|------|------|------|
| 语言 | Swift 5.9+ | 使用 strict concurrency checking |
| UI 框架 | SwiftUI | 使用 `@Observable` 宏 (Observation framework)，**不使用** ObservableObject/Published |
| 音频核心 | AVFoundation (AVAudioEngine) | 封装为 `AudioService` actor，单例模式，管理所有录音/播放状态机 |
| TTS | AVSpeechSynthesizer | 封装在 `AudioService` 内部 |
| 数据持久化 | SQLite (via swift-sqlite 或 GRDB.swift) | 封装为 `DataService` actor |
| 包管理 | Swift Package Manager | 不使用 CocoaPods/Carthage |
| 最低部署目标 | macOS 14.0 (Sonoma) | |

### 5.2 架构约束

- **MVVM 架构：** View → ViewModel (`@Observable`) → Service (Actor)。
- **音频状态机：** `AudioService` 内部维护严格的状态机：`idle → recording → playing(source) → playingABAB`。禁止非法状态跳转，所有状态转换通过 `enum AudioState` 和 `switch` 实现。
- **线程安全：** `AudioService` 和 `DataService` 必须是 Swift Actor，所有外部调用通过 `await`。
- **错误处理：** 所有可失败操作使用 `Result` 类型或 `throws`，UI 层通过 alert 展示错误。

### 5.3 部署与分发

- 纯 Mac 本地应用，不上架 Mac App Store。
- 用户通过源码编译运行（`swift build` / Xcode open）。
- 提供 Makefile 或 `justfile` 简化构建。

### 5.4 隐私与网络

- **离线优先 (Offline-First)：** 日常训练 100% 本地，无网络调用。
- 录音数据存储在 `~/Library/Application Support/PhoneticsMaestro/recordings/`，按 session 日期分目录。
- 录音文件格式：CAF (Core Audio Format) 或 M4A，44.1kHz，单声道。

---

## 6. 开发阶段划分 (Implementation Phases)

### Phase 1: 基础骨架 (Skeleton)
- [ ] Xcode 项目初始化，SPM 依赖配置
- [ ] SQLite 数据层 (`DataService`)，含 schema migration
- [ ] 种子数据 JSON 导入 (`SeedDataImporter`)
- [ ] 基础 SwiftUI 导航结构（Welcome → Training Card）

### Phase 2: 音频核心 (Audio Engine)
- [ ] `AudioService` actor 实现，含状态机
- [ ] TTS 标准音播放
- [ ] 麦克风录音（权限请求 + 录音 + 保存）
- [ ] 单轨回放（Me / Standard）
- [ ] ABAB 循环播放（含 300ms 间隔）

### Phase 3: 训练卡片 (Training Card)
- [ ] 目标展示区 UI
- [ ] 听辨模块（Random Test + 判断 + 反馈）
- [ ] 练习模块 UI（录音 + 回放按钮组）
- [ ] 状态打标（Save / Hard）
- [ ] 会话统计实时更新
- [ ] 卡片导航 + 键盘快捷键

### Phase 4: 收尾 (Polish)
- [ ] History 页面（统计汇总）
- [ ] Settings 页面
- [ ] 侧边栏折叠
- [ ] 错误处理与 edge case
- [ ] 基础 UI 动画（录音脉冲、反馈高亮）

---

## 7. 未来演进规划 (Roadmap — V2+)

架构设计时需预留多语言支持的扩展槽（Extension Slots）：

- **CLI 数据管线 (V2):** 独立命令行工具，调用 LLM API 生成训练数据，写入 SQLite。预留 `DataImportService` protocol。
- **西班牙语支持 (V2):** 适应高规律性拼读，增加大舌音 (rr) 和句间元音连读 (Sinalefa) 专项卡片。
- **日语支持 (V3):** 调整对比逻辑为"音拍时长 (Mora)"与"高低声调 (Pitch Accent)"。
- **频谱可视化 (V2):** 对比用户录音和标准音的波形/频谱图，提供视觉反馈。
