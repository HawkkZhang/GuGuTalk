# Handoff

This file is the first-stop handoff note for switching between Codex, Claude Code, Xcode, and other development tools.

## Recent Fixes - 2026-05-10

### 深色模式设置页降亮度与可读性调整（本地已实现，待用户体验确认）

**用户反馈：**
- 当前 UI 在深色模式下略显刺眼，尤其是设置界面。
- 主要问题是文字不够清楚，大面积青色在暗色模式下有些顶眼。

**本轮调整：**
- 使用 `frontend-design` 方向做了暗色模式专项微调，不重做页面结构。
- `DVITheme` 的暗色 aqua 从亮青白压到更深的水青，选中态仍明显，但不再像发光色块。
- 暗色面板、侧栏、控件、分隔线整体降低饱和度，从大面积青色改为低饱和 charcoal-teal。
- 设置页背景的青色氛围层透明度降低，减少整页被青色罩住的感觉。
- `DESIGN.md` 增加 `Dark Aqua Rule`，要求暗色模式里 aqua 只做强调，不做大面积环境光。

**验证：**
- `swift test` passed：19 tests。
- Debug `xcodebuild` passed。
- Release `xcodebuild` passed。
- Latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`，PID `43633`。

### 豆包 terminal final 偶发丢开头前缀（本地已实现，待用户实测确认）

**用户反馈：**
- 说长句时，开头内容一开始在流式气泡里出现过，但最终上屏时消失。
- 真实例子：用户开头说了 “Gemini”，partial 里已经出现 `Gemini`，但 final 只剩 `之前还挺好用的。`。

**本轮实锤：**
1. 查看 `~/Library/Logs/GuGuTalk/doubao-transcripts.log` 后确认，不是插入服务或后处理删掉了开头。
2. 同一次会话中，第 3 帧为 `previous="Gemini." raw="Gemini 之前还"`，第 4 帧 terminal raw 直接变成 `raw="之前还挺好用的。"`。
3. 这说明豆包 terminal `result.text` 偶发把上一帧已经稳定出现的前缀丢掉。客户端原先严格信任 terminal `result.text`，所以把缺前缀的文本当 final 上屏。

**本轮修复：**
- 保持官方语义：豆包仍使用 `result_type = "full"`，常规 partial/final 仍直接以服务端 `result.text` 替换，不做 partial 拼接。
- 新增 `DoubaoTranscriptRepair.recoverFinalText(current:previous:)`，只在 `terminal && finishRequested` 时生效。
- 修复条件很保守：
  - 当前 terminal final 不是上一帧的完整前缀延续；
  - 上一帧尾部和当前 final 开头有至少 2 个语义字符的精确重叠；
  - 被补回的前缀至少有 1 个语义字符；
  - 否则完全不改服务端 final。
- 诊断日志现在增加 `emitted` 和 `repairedFromPrevious` 字段。再次复现时可以直接看应用最终实际发出的文本是否经过修复。

**验证：**
- `swift test` passed：19 tests。
- Debug `xcodebuild` passed。
- Release `xcodebuild` passed。
- Latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`，PID `36210`。

### 豆包偶发重字与音频结束包顺序（本地已实现，待用户实测确认）

**用户反馈：**
- 豆包仍偶发重字，例如“那我现在用用的就是 XUDP”，用户确认自己没有说两个“用”。

**本轮定位：**
1. 当前豆包解析逻辑并不是把 partial 拼接起来；`result_type = "full"` 时，每次会直接用服务端 `result.text` 替换 `latestTranscript`。
2. 本机设置确认 `postProcessingEnabled = 0` 且识别模式是豆包，所以这类重字不是 AI 后处理改出来的。
3. 近期日志里多次出现豆包协议错误：`last packet has been received already`。这更像是音频包和结束包并发发送导致最后一包先到，随后还有旧音频包抵达，服务端没有稳定返回 final；应用再用不稳定 partial 兜底上屏，就可能带出 partial 阶段的重复字。

**本轮修复：**
- `RealtimeWebSocketTransport` 新增异步发送锁，所有 WebSocket `send(text:)` / `send(data:)` 串行执行，确保音频帧和 finish 帧按调用顺序到达服务端。
- 豆包每一帧识别结果都会输出 `[DoubaoTranscript]` 诊断：`previous`、`raw`、`normalized`、`resultTexts`、`utterances`、`lostPreviousPrefix`。
- 同一份诊断也会写入 `~/Library/Logs/GuGuTalk/doubao-transcripts.log`。如果出现“Gemini 一开始有、后面没了”，查 `lostPreviousPrefix=true` 附近的几行即可判断是豆包 raw 已经删掉，还是客户端处理/上屏删掉。

**验证：**
- `swift test` passed：16 tests。
- Debug `xcodebuild` passed。
- Release `xcodebuild` passed。
- Latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`，PID `32371`。
- Current local Doubao transcript log was truncated before user retest: `~/Library/Logs/GuGuTalk/doubao-transcripts.log`。

### 快速重启录音时主动结束上一段会话（本地已实现，待用户实测确认）

**用户反馈：**
- 快速重新长按或再次触发语音输入时，如果上一段识别/后处理还没有自动结束，新会话可能无法正常开始录音。

**本轮修复：**
- `VoiceInputAppModel` 不再简单忽略“已有会话时的新触发”；如果用户再次手动触发录音，会先走 restart 流程，取消上一段未完成工作，再启动新的 hold-to-talk 或 toggle-to-talk 会话。
- `RecognitionOrchestrator` 新增 `hasActiveWork` 和 `cancelActiveWorkForRestart(reason:)`，统一清理启动中 provider、活跃 provider、音频采集、final timeout、dismiss task、AI 后处理 task、provider event task。
- provider 启动、音频发送、provider 事件、AI 后处理结果都绑定 `sessionGeneration`；旧会话晚到的事件或结果会被忽略，不再覆盖/结束新会话。
- 正在握手但还没变成 `activeProvider` 的 provider 也会被记录为 `startingProvider`，快速重启时可以一起取消，避免旧连接晚回调干扰新录音。

**验证：**
- `swift test` passed：16 tests。
- Debug `xcodebuild` passed。
- Release `xcodebuild` passed。
- Latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`，PID `27079`。

### 长按说话提前中断与 GuGuTalk 内输入限制（本地已实现，待用户实测确认）

**用户反馈：**
- 按住说话时，用户还没有松开热键，录制却会自己停掉；托盘/系统看起来麦克风仍被占用。
- 需要“实锤”豆包最终返回是否自带停顿空格，不能只靠猜测。
- GuGuTalk 自己的设置页里也应该允许语音输入，例如用户编辑 Prompt 或服务参数时。

**本轮定位：**
1. `RecognitionOrchestrator` 在 provider 中途失败且已有 partial 的路径，会把 partial 当作最终结果插入，但旧代码没有在该路径统一停止 `AudioCaptureEngine`，可能造成“会话结束但麦克风仍占用”的状态错位。
2. `VoiceInputAppModel.updateHotkeyMonitoring()` 每次权限刷新都会调用 `hotkeyManager.start()`；旧 `start()` 内部会先 `stop()`，在按住期间可能重置热键状态。现在 `start()` 对已启动的 event tap 幂等，不再重建。
3. `TextInsertionService` 旧逻辑只要发现前台应用是 GuGuTalk 就直接拒绝插入，这个保护过粗，会误伤设置页里的 Prompt / API 参数输入框。
4. `AppSettings.recognitionConfig` 旧端点策略是 `.voiceActivityDetection`，与当前产品交互“用户松开/再次按下才结束”不一致。

**本轮修复：**
- 热键监听：
  - `HotkeyManager.start()` 改成幂等；权限刷新不会反复 stop/start event tap。
  - 热键 press/release、modifier press/release、event tap 被系统禁用重启都增加日志。
  - 快捷键录制仍通过 `suspendHotkeys()` 暂停全局热键，录制结束恢复；不再需要禁用整个 GuGuTalk 应用内语音输入。
- 会话收尾：
  - `finishSession(reason:)`、`forceEndSession()`、provider failure with partial 等所有终止路径统一调用 `stopAudioCapture(reason:)`。
  - provider failure、最终文本管线、插入结果均增加日志，便于判断是热键释放、provider 断开、final 超时还是插入失败。
- 识别端点：
  - `RecognitionConfig.endpointing` 改为 `.manual`，让按住说话/按一下开始停止都由用户动作决定收尾，而不是由服务端 VAD 根据停顿提前结束。
- GuGuTalk 内输入：
  - 移除“前台是 GuGuTalk 就拒绝”的一刀切逻辑。
  - 新逻辑：如果前台是 GuGuTalk，只有当前焦点不是文本输入控件时才拒绝；Prompt、配置输入框等可编辑控件可以正常用语音输入。
- 豆包 raw 证据：
  - Doubao provider 现在在 terminal / finish 相关事件以及 raw 被 normalizer 改动时输出 `raw` 和 `normalized` 对照日志。
  - raw 日志保留换行/制表符的可见转义，不再只做 Debug-only，也不再只在 Debug 构建可见。

**验证：**
- Debug `xcodebuild` passed。
- Release `xcodebuild` passed。
- `swift test` passed：16 tests。
- Latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`，PID `3443`。

**下一步实测建议：**
- 用豆包模式按住说一段中间有明显停顿的长句，观察是否还会未松手提前结束。
- 如还有问题，查看 Console 或 Xcode 日志中 `HotkeyManager`、`RecognitionOrchestrator`、`DoubaoSpeechProvider` 三类日志即可定位：热键 release 是否真的发生、provider 是否提前失败、豆包 final raw 是否带空格。

## Recent Fixes - 2026-05-09

### 录音气泡一致性与豆包中文空格清理（2026-05-10，本地已实现，待用户体验确认）

**用户反馈：**
- 等待识别的波形气泡和识别中的文本气泡颜色不一致。
- 气泡圆角外还有隐约的方框/背景。
- 豆包最终上屏结果里会在停顿处分出额外空格，例如“过程中 就 会有空格”。

**本轮调整：**
1. 录音 overlay 正常状态统一使用同一图标 aqua 主题底色；空文本波形和识别文本不再使用两套颜色。
2. `NSHostingView` 显式设为透明 layer，overlay 去掉外层投影并 clip 到统一形状，降低圆角外出现方形背景的概率。
3. 新增 `TranscriptTextNormalizer.normalizeSpeechText`，移除中文汉字之间、中文标点附近的空格，但保留英文词间空格，例如 `OpenAI Cloud`。
4. 豆包 provider 在入口处使用同一 normalizer，所以 partial、final、最终上屏前都会走一致的中文空格清理。
5. Debug 构建下新增豆包 raw/normalized 对比日志：当服务端原文和应用使用文本不一致时，会输出 `raw=... normalized=...`，便于确认空格是否来自服务端返回。
6. 补充测试用例覆盖中文停顿空格清理、英文空格保留、豆包 raw/canonical 对比。

**验证：**
- Debug `xcodebuild` passed。
- `xcodebuild test` 不能执行：当前 scheme 未配置 test action。
- 临时 Swift 脚本验证：`在这个停顿的过程中 就 会有空格` -> `在这个停顿的过程中就会有空格`；`打开 OpenAI Cloud 控制台` 保持英文词间空格。
- Debug app 已从 `/tmp/DesktopVoiceInputDerivedData/Build/Products/Debug/DesktopVoiceInput.app` 重启。

### 句尾标点规则修正（2026-05-10，本地已实现，待用户体验确认）

**用户反馈：**
- 豆包最终结果里问句有问号，但最终上屏后问号没了。

**定位：**
- 当前用户设置 `punctuationMode = removeTrailing`。
- UI 文案是“去掉句尾句号”，但 `TextTransform.removeTrailingPunctuation` 旧实现会移除句尾所有 punctuation/symbol，包括 `？` 和 `！`。

**修复：**
- `removeTrailingPunctuation` 现在只移除句尾句号类字符：`。`、`.`、`．`、`｡`。
- 问号和感叹号会保留。
- 测试已同步更新，覆盖“真的吗？！”保留，以及“今天先这样。。”去掉句尾句号。

### UI 重建设计方向：Aqua Chick Companion（2026-05-10，本地已实现，待用户体验确认）

**用户反馈：**
- 上一版仍然太丑、太粗糙，气泡有灰色/半透明玻璃感，配色缺少品牌记忆点。
- 希望不用 `impeccable`，改用项目内 `frontend-design` 思路重新设计。
- 目标：精致、轻快、有一点品牌感，但不花哨；不全靠灰色和系统蓝；不要霓虹、发光、赛博感。

**本轮设计方向：**
- 新视觉北极星：`Aqua Chick Companion`。
- 主题色从 App 图标提取：清透青蓝作为主色，嘴/脚的暖橙只做少量强调。
- 保留系统字体和 Mac 桌面工具的克制感，但不再依赖系统灰、系统蓝和原生开关。
- 录音气泡改为实体浮层，不使用半透明玻璃拟态，也不保留粗糙外框。

**本轮代码调整：**
1. `DVITheme` 重建为图标青蓝主题，并新增统一的 `DVIChoiceBar`、`DVISwitch`、`DVIAppIcon`。
2. 输入气泡关掉 NSPanel 自带阴影，去掉额外留白和正常状态线框，避免出现异常外框。
3. 菜单栏控制台重做为迷你控制台：真实 App 图标、状态卡、识别模式切换、缺权限提示、设置/退出操作。
4. 设置页重做层级：左侧为输入/整理/权限，输入页只保留识别引擎、云端配置、触发方式、外观；本地模式不显示无意义配置说明。
5. 系统 Toggle / Picker / bordered button 已从当前 SwiftUI 页面移除，改为自定义精致控件。
6. 权限引导卡片同步调整为同一视觉语言。
7. `DESIGN.md` 已更新为新的图标主题设计系统，避免后续工具按旧的系统蓝灰或玉绿方向继续改。

**验证：**
- `swift test` passed: 12 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed
- Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app`
- Debug app direct launch仍受 Xcode debug dylib 本地签名限制影响，建议真实体验继续使用 Release build。

### 豆包流式重复字修复：按官方 utterances 语义重接（已实现，待真实长句验证）

**问题描述：**
- 用户在豆包模式下仍遇到明显重复字，例如“整整个应用的颜色”“有有重复”。
- 这类重复更像客户端把旧 partial、当前 partial、二遍识别 final 的边界处理错了，而不是单纯 ASR 识别质量问题。

**官方文档核对：**
- `result_type` 默认为 `full`，代表全量返回。
- 设置 `result_type = "single"` 时，返回增量结果，不返回之前分句。
- `show_utterances = true` 后，`utterances[].definite` 才能标记一个分句是否已经确定。
- `enable_nonstream = true` 会开启流式 + 非流式二遍识别，最终准确性依赖确定分句语义，客户端不能只盲拼 `result.text`。

**本轮修复：**
1. 豆包请求改为 `show_utterances: true`、`result_type: "single"`，不再只吃整段 `result.text`。
2. 新增 `DoubaoTranscriptAssembler`：
   - `definite=true` 的 utterance 进入已确认文本。
   - `definite=false` 的 utterance 只作为当前临时预览段，后续 partial 到来时替换，不追加。
   - 已确认文本和临时文本的边界做重叠合并，避免“有 + 有一个”变成“有有一个”。
3. `DoubaoTranscriptPayload` 同时兼容 `result` 为对象和列表两种结构，避免官方字段描述与示例结构差异导致解析脆弱。
4. 增加 4 个豆包解析/组装测试，覆盖 utterances 解析、全量式已确认文本去重、边界重叠合并、active partial 替换而非追加。

**验证：**
- `swift test` passed: 12 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed
- Latest Release build installed and launched at `/Applications/GuGuTalk.app`

**2026-05-10 复审更新：**
- 用户指出这个接口本身应负责流式结果刷新，客户端不应过度组装。
- 复审后采用更简单的官方语义：`result_type = "full"`，每次收到结果都直接以服务端完整 `result.text` 替换当前预览和 latest final。
- `show_utterances = true` 保留用于调试和兜底解析，但不再用本地 assembler 拼接分句。
- `result` 兼容 object 和 list；优先使用服务端 `text`，只有没有 `text` 时才按 utterances 时间顺序兜底。
- 这样避免客户端自己制造 “旧 partial + 新 partial” 的重复字。
- 本次复审后：`swift test` passed 12 tests；Debug/Release `xcodebuild` passed；最新版已安装到 `/Applications/GuGuTalk.app`。

### 设计风格重建：Porcelain Lake（已实现，待用户体验确认）

**本轮目标：**
- 用户明确反馈上一版仍然太丑：输入气泡灰、不规则玻璃感明显、配色没有品牌感，设置页和托盘也缺少统一设计判断。
- 这轮不再继续微调旧视觉，而是重建一套更有识别度的产品 UI：清爽但不寡淡，精致但不花哨，仍保留 macOS 系统字体和桌面工具的克制感。

**设计方向：**
- 视觉关键词：瓷感、湖蓝、安静、轻快、克制。
- 不使用装饰性玻璃拟态，不使用灰色临时浮层，不做网页后台式卡片堆砌。
- 主色从系统蓝灰改为湖蓝/青绿色系；状态色保持明确：湖蓝表示当前选择，薄荷绿表示就绪，珊瑚红表示错误。

**本轮调整：**
1. `DVITheme` 重建色彩和形状 token：统一窗口、侧栏、面板、控件、浮层、选中态、状态色。
2. 输入气泡移除不规则半透明玻璃背景，改为实体瓷感 HUD；短状态更轻，识别内容展开时最多三行，仍保留最新内容并从开头省略。
3. 识别波形在无文本时作为主状态，在有文本后退到背景信号，不再占据一块生硬空间。
4. 菜单栏控制台改成更紧凑的状态面板：状态、模式、权限提醒、设置入口和退出入口，减少无效“已就绪”信息堆砌。
5. 设置页重建侧栏品牌区、页面标题、分组面板、快捷键按钮和 provider 状态芯片；快捷键区域使用开关加“更改”按钮，信息更直接。
6. 后处理页、权限页实机切换检查过，当前视觉语言与常用页保持一致。

**验证：**
- `swift test` passed: 8 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed
- Latest build installed and launched at `/Applications/GuGuTalk.app`
- Used Computer Use to inspect the live Settings window across Common, Post-processing, and Permissions pages.

### 设计风格试验：Polished Mac Companion（已实现，待用户体验确认）

**本轮目标：**
- 用户明确反馈上一版太素，且输入状态圆角矩形气泡缺乏审美。
- 设计方向从“尽量原生”调整为“精致的 Mac 第三方工具”：保留系统字体和原生控件，同时增加轻盈层次、清爽主色和更漂亮的输入浮层。

**本轮调整：**
1. 输入气泡从硬圆角卡片改为轻浮岛 HUD：短状态更小，录音时更像临时系统浮层，展开后保持柔和形态。
2. 识别文本最多展示三行，继续遵守“保留最新内容，省略最早内容”的规则。
3. 波形在有文字时弱化为背景信号，不再像独立占位组件。
4. 设置页减少重复状态信息，删掉侧栏底部状态条，让状态只在相关位置出现。
5. 快捷键文案压缩为“松开后插入”“再次按下结束”，并给快捷键按钮增加可编辑暗示。
6. 外观设置重新放回统一面板，避免裸露控件破坏节奏。
7. 主题色从生硬系统蓝灰调整为更清爽的湖蓝/青绿色系，深浅色都保留克制感。

**验证：**
- `swift test` passed: 8 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed
- Latest build installed and launched at `/Applications/GuGuTalk.app`

### UI 信息层级与视觉语言精修（已实现，待用户体验确认）

**本轮目标：**
- 按照 `PRODUCT.md`、`DESIGN.md` 和 impeccable 设计标准重新审视设置页、菜单栏控制台、输入气泡。
- 方向是更接近 native macOS：克制、清晰、紧凑、有质感，避免网页后台感、花哨 AI 工具感，以及圆形/胶囊/圆角矩形混用导致的杂乱感。

**本轮调整：**
1. 菜单栏控制台改为紧凑状态头：状态标记、当前状态、快捷键提示、识别模式切换、缺权限时才显示处理提示。
2. 设置页快捷键区域从两张大卡片改为一个分组面板内的两行设置，使用原生开关和更少说明文字，降低视觉噪音。
3. 输入气泡外形从胶囊改为统一的连续圆角面板，背景材质更稳，避免小气泡/大气泡和设置页组件形状语言割裂。
4. 状态颜色统一走 `DVITheme`，减少硬编码红/蓝/橙/白，选中态和提示态更一致。
5. 快捷键录制冲突提示、警告提示统一为轻量状态条，避免橙色大段提醒破坏设置页平衡。

**验证：**
- `swift test` passed: 8 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed
- Latest build installed and launched at `/Applications/GuGuTalk.app`

### 结束阶段误报“识别未完成，已插入部分结果”（已修复，待真实长句验证）

**问题描述：**
- 用户说一句话或稍长内容时，经常看到“识别未完成，已插入部分结果”。
- 这句提示来自 `RecognitionOrchestrator` 的失败兜底逻辑：provider 发出 `sessionFailed`，但当前已有 partial 文本，于是应用把 partial 当作最终文本插入。

**本轮定位：**
- 千问 provider 的 `onDisconnected` 之前会把任何带 error 的 WebSocket 断开都上报为 `sessionFailed`，即使用户已经松手并发送了 `session.finish`。
- 豆包 provider 在 `finishAudio()` 后的断开阶段，虽然会尝试用 `latestTranscript` 兜底发 final，但仍可能继续往下走到断开错误分支。
- 编排层收到“已经有 final 之后的失败事件”时，之前仍可能把会话改成失败状态。

**本轮修复：**
1. 千问：增加 `latestTranscript` 和 `hasTerminatedSession`，结束阶段断开时优先发 final 并正常结束，不再误报失败。
2. 豆包：`hasRequestedFinish` 或已发 final 后的断开直接正常结束，不再继续上报连接失败。
3. 编排层：如果 `finalTranscript` 已经生成，忽略后到的 provider failure，避免成功插入后又显示失败。
4. AI 后处理成功完成后清空 overlay transcript，并在插入成功后立即关闭气泡；不再显示“已插入”状态，也不再重新展示大段识别结果。

**验证：**
- `swift test` passed: 8 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed; latest build installed and launched at `/Applications/GuGuTalk.app`

### AI 后处理气泡样式问题（已修复，待用户体验确认）

**问题描述：**
- "AI 处理中"状态的气泡大小不正确
- 用户期望：应该像其他系统状态（波形、提示）那样是**小气泡**
- 原因：后处理开始时 `RecognitionOrchestrator` 会保留最终识别文本在 `PreviewState.transcript` 中，同时设置 `isPostProcessing = true`。旧的 overlay 尺寸计算先读取非空 transcript，因此仍按“识别结果大气泡”计算大小；尺寸监听也没有监听 `isPostProcessing`，所以状态切换时不会主动缩回。

**本轮修复：**
1. `PreviewOverlayController.bind()` 增加监听 `PreviewState.isPostProcessing`，AI 处理状态变化会触发 overlay 重新计算尺寸。
2. `panelSize(for:)` 中将 `isPostProcessing` 提前到 transcript 尺寸计算之前，固定返回小气泡尺寸 `172x54`。
3. 为 `isPostProcessing` 状态增加轻柔尺寸动画，避免从结果气泡切换到处理气泡时突兀跳变。

**相关代码：**
- `Sources/DesktopVoiceInput/Services/PreviewOverlayController.swift:149-188`
- `PreviewState.isPostProcessing` 状态
- `postProcessingIndicator` 视图

**验证：**
- `swift test` passed: 8 tests
- Debug `xcodebuild` passed
- Release `xcodebuild` passed; latest build installed and launched at `/Applications/GuGuTalk.app`

---

## Historical Critical Issues - 2026-05-07

**权限流程曾导致应用处于不可用状态。相关修复已经进入当前代码和打包流程；后续用户测试没有再确认同类权限阻塞。这里保留为历史风险和回归测试背景。**

1. **申请语音识别权限导致闪退**
   - 点击"语音识别"的"立即申请"按钮后应用崩溃
   - 位置：`PermissionCoordinator.refreshSpeechRecognition(prompt: true)`
   - 已处理：权限请求显式在主线程发起，并在主线程恢复结果

2. **启动时自动弹出权限请求对话框**
   - 应用启动后直接弹出系统辅助功能权限请求
   - 期望：应该先打开设置窗口，让用户主动点击后才请求
   - 已处理：启动只做静默权限检查；全局热键监听仅在输入监控已授权时启动；缺权限时自动打开设置窗口

3. **权限检测不准确**
   - 用户在系统设置中授予权限后，应用仍显示"未授权"
   - 已定位：麦克风权限缺失的真实原因是 Hardened Runtime 下应用缺少 `com.apple.security.device.audio-input` entitlement，导致系统麦克风权限列表不出现 GuGuTalk
   - 已处理：Release 构建使用本地稳定签名 `GuGuTalk Local Code Signing`；新增 `Config/DesktopVoiceInput.entitlements`；刷新检查统一走 AppModel，刷新权限后同步热键监听状态
   - 后续用户测试基本恢复；仍需作为权限回归场景持续验证

**详细问题记录见 `BUGS.md`**

## Current Stable Point

- Stable tag: `stable-2026-05-01`
- Stable commit: `960f2b3`
- GitHub repository: `https://github.com/HawkkZhang/GuGuTalk`
- Latest synced checkpoint is on `main`; use `git log --oneline -1` for the exact current commit.
- Local branch at time of writing: `main`
- Remote branch: `origin/main`

If local work gets messy, use the stable tag as the known-good restore point.

## Latest Synced State - 2026-05-10

The latest synced code checkpoint is on `main`; use `git log --oneline -1` for the exact commit.

Current implemented state:

- Doubao currently uses `result_type = "full"` and treats provider `result.text` as the full replacement transcript.
- Official Doubao `bigmodel_async` reference: `https://www.volcengine.com/docs/6561/1354869?lang=zh`. The relevant contract is `result_type = "full"` for full transcript refresh, while `single` is incremental and does not include previous segments.
- `show_utterances = true` remains enabled for diagnostics and fallback parsing, but the client no longer assembles normal transcript text from `utterances[].definite` when `result.text` is present.
- The earlier `result_type = "single"` / local utterance assembler approach was tried and then retired because it increased the risk of client-side duplicate or missing text.
- Terminal final has a narrow prefix-repair guard only for the observed edge case where Doubao terminal `result.text` drops a stable prefix from the previous update.
- Occasional repeated-character reports still need log-based verification. Check `[DoubaoTranscript] raw`, `normalized`, and `emitted` before adding any new local correction.
- The primary settings/onboarding entry now uses a dedicated AppKit `NSWindow`, not SwiftUI `Settings {}` or a bridge-based settings scene.
- Documentation audit completed on 2026-05-10: README, DESIGN, CONTRIBUTING, BUGS, MEMORY, and HANDOFF have been aligned with the current implementation for macOS target, hotkeys, AppKit settings window, Doubao `result_type = "full"`, custom controls, local test coverage, and self-text-field insertion behavior.

Desired app-entry behavior:

- Every time the user opens GuGuTalk from Finder, Launchpad, or `/Applications`, the app should show the main settings/onboarding window.
- If required permissions are missing, open directly to the Permissions page.
- If permissions are ready, open to the General/Home page.
- The app should still remain a menu bar utility for day-to-day recording, but launch should not feel like the app disappeared into the menu bar.

## Product Snapshot

This is a macOS-only desktop voice input app. It is not a system IME. The product shape is:

- menu bar app
- global hotkeys
- small floating recognition preview
- final text insertion into the currently focused app
- local Apple Speech, Qwen realtime, and Doubao realtime providers

Default user experience:

1. User triggers recording with a configured shortcut.
2. The overlay shows recording state and streaming transcript.
3. On stop, final text is post-processed.
4. The app inserts final text into the active input target.

## Source Of Truth Files

Read these before starting work:

- `PRODUCT.md`: product purpose, users, personality, anti-references.
- `DESIGN.md`: visual language, layout rules, component rules, recording overlay rules.
- `MEMORY.md`: current status, unfinished functionality, risk areas.
- `README.md`: high-level implementation and run instructions.
- `HANDOFF.md`: current operational handoff.

When switching tools, update `HANDOFF.md` if the next step, risk, or known-good state changes.

## Artifact Management

- Canonical local DMG output directory: `dist/dmg/`.
- Packaging command: `./scripts/package-dmg.sh`.
- The script builds Release, stages `GuGuTalk.app`, creates a compressed DMG, verifies it, and writes a `.sha256` checksum next to it.
- Do not create DMGs in the repo root, `Packages/`, Desktop, Downloads, or arbitrary temp folders.
- `dist/dmg/*.dmg` and `dist/dmg/*.sha256` are local artifacts and must not be committed.

## Recent State

The app currently has:

- a SwiftUI/AppKit menu bar shell
- settings UI with pages for input, post-processing, and permissions
- app-entry settings guidance is implemented with a dedicated settings/onboarding window; every app launch/reopen should show that window, with Permissions selected when required permissions are missing
- two shortcut modes:
  - hold-to-talk
  - press-once-to-start, press-again-to-stop
- local Apple Speech provider
- Qwen realtime provider
- Doubao realtime provider
- floating preview overlay
- post-processing and insertion pipeline
- design documentation and project memory
- local Release install at `/Applications/GuGuTalk.app`, signed with `GuGuTalk Local Code Signing`

The most recent UI direction is:

- native macOS feel
- calm and restrained
- system font
- system light/dark appearance support
- no flashy AI styling
- no web-admin or game-panel feeling
- compact overlay with waveform only before text, then waveform embedded quietly behind transcript text
- newest transcript content should remain visible, with a single leading ellipsis when older text is omitted

Latest local fix:

- Hold-to-talk cutoff was traced to a stale final-result timeout task, not to a real hotkey release.
- `RecognitionOrchestrator` now scopes final timeout tasks by `sessionGeneration`, cancels old timeouts at session start/end, and ignores duplicate `endCapture()` calls after finishing has begun.
- Lifecycle expectation is: starting can accept a pending stop, recording streams audio, finishing sends `finishAudio()` once, idle clears all pending stop / finish / timeout state.
- System hint bubbles now use the same aqua overlay surface as recording; only prompt text style changes.
- Verified locally on 2026-05-10: Debug build passed, Release build passed, `swift test` passed 16 tests, latest Release app launched from `/tmp/DesktopVoiceInputReleaseDerivedData/Build/Products/Release/DesktopVoiceInput.app` with PID `11291`.

## Known Risks

- Settings/onboarding architecture now uses a dedicated AppKit settings window. Keep verifying Finder/Launchpad/menu bar entry behavior on packaged builds and different macOS/signing states.
- The locally signed `/Applications/GuGuTalk.app` is for development testing. It may still be blocked by Gatekeeper when double-clicked because the certificate is self-signed; launching via `/Applications/GuGuTalk.app/Contents/MacOS/DesktopVoiceInput` is currently the most reliable local test path.
- Do not assume hotkeys are fully stable. Dual hotkey mode still needs testing and polish.
- If hold-to-talk is still cut off, inspect logs for `HotkeyManager` release events versus `RecognitionOrchestrator` timeout/provider events. A cutoff without release should now show whether it is provider failure, sendAudio failure, or a new lifecycle bug.
- Do not let shortcut recording trigger live voice input.
- Allow voice input inside GuGuTalk's own editable text fields, including prompts and provider configuration fields; block insertion only when the focused GuGuTalk element is not editable.
- Treat text insertion compatibility as a top-priority product risk. Browser and web rich-text editors can expose placeholder / hint text through Accessibility APIs, so direct AX read-modify-write can accidentally merge hint text into the dictated result. Prefer paste-style insertion for browsers / web editors, keep Accessibility insertion for safe native controls, and build toward per-app strategy memory plus full pasteboard restoration.
- Cloud provider credentials live in local user defaults and are not committed.
- macOS permissions are per-machine and are not committed.
- Xcode signing/distribution is not production-ready.
- GitHub sync stores source code, not installable app artifacts.

## Next Recommended Work

1. Verify Doubao occasional repeated-character reports with real `[DoubaoTranscript]` logs before changing result handling again.
2. Continue testing the dedicated settings/onboarding window from Finder, Launchpad, `/Applications`, and menu bar Settings.
3. Stabilize hotkey state transitions.
4. Harden the text insertion pipeline for browsers, rich-text editors, Electron apps, and native text fields.
5. Improve provider configuration validation before a recording session starts.
6. Improve provider visibility in the menu bar console and errors.
7. Add automated tests for hotkeys, insertion guards, and provider selection.
8. Eventually set up signing, packaging, and release artifacts.

## Suggested Prompt For Another AI Tool

Use this when opening Claude Code or another coding agent:

```text
Please first read PRODUCT.md, DESIGN.md, MEMORY.md, HANDOFF.md, README.md, and the latest git log.
This is a macOS SwiftUI/AppKit voice input app named GuGuTalk / DesktopVoiceInput.
Continue from the latest `main`.
The app already uses a dedicated AppKit settings/onboarding window for Finder/Launchpad app open, app reopen, menu bar Settings, and permission guidance.
If permissions are missing, that window should open to Permissions; otherwise it should open General/Home.
Preserve the current Doubao `result_type = "full"` strategy unless real `[DoubaoTranscript]` logs prove local processing is wrong.
Do not overwrite uncommitted changes if any exist in the local checkout.
Respect the native macOS design direction and the known risks in HANDOFF.md.
Before editing, inspect the relevant files and summarize the intended change.
After a stable change, build with xcodebuild, commit, and push.
```

## Useful Commands

Build:

```bash
xcodebuild -project DesktopVoiceInput.xcodeproj -scheme DesktopVoiceInput -configuration Debug -derivedDataPath /tmp/DesktopVoiceInputDerivedData build
```

Package local DMG:

```bash
./scripts/package-dmg.sh
```

Run the debug app:

```bash
open /tmp/DesktopVoiceInputDerivedData/Build/Products/Debug/DesktopVoiceInput.app
```

Check status:

```bash
git status --short --branch
git log --oneline -5 --decorate
```

Return to current stable checkpoint only if intentionally discarding local work:

```bash
git switch -C restore-stable stable-2026-05-01
```

Do not run destructive reset commands unless the user explicitly approves discarding local changes.
