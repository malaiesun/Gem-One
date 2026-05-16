# Gem One - Technical Writeup
### Gemma 4 Good Hackathon - Kaggle 2026

---

## What It Is

Gem One is an offline-first AI assistant for Android built for communities with no reliable internet access. It runs Google's Gemma 4 E4B language model entirely on-device via the LiteRT runtime - no cloud calls, no accounts, no data leaving the phone. Six AI modules share a single model instance: Medical Advisor, Scholar, Language Tutor, DocWriter, General Assistant, and Math Tutor, alongside a standalone Calculator and offline Reference tool.

The goal is simple: a student with no data plan, a rural health worker, or anyone in a low-connectivity region should have access to the same quality of AI assistance as someone with broadband. Gem One delivers that from a single APK.

---

## Model and Runtime

**Model:** Gemma 4 E4B (`gemma-4-E4B-it.litertlm`, ~3.5 GB quantized binary)
**Package:** `flutter_gemma` v0.15.0, LiteRT GPU backend (`PreferredBackend.gpu`)
**Context:** 1024 tokens per turn, vision enabled (`supportImage: true`)

Gemma 4 E4B hits the right balance between on-device feasibility and reasoning quality. Larger variants (26B, 31B) require dedicated hardware; E4B runs on a capable Android device with sufficient free RAM.

`flutter_gemma` has no native system-prompt API. Each module injects its persona as the first user-side message before any real conversation begins:

```dart
final chat = await _model!.createChat();
final systemPrompt = customPrompt ?? getMissionPrompt(mission);
await chat.addQueryChunk(Message.text(text: systemPrompt, isUser: true));
```

This lets one model instance serve six distinct personas by simply switching the injected prompt at session start - no model reloading required.

---

## Architecture

```
main.dart
  +-- FlutterGemma.initialize()       # LiteRT bootstrap
  +-- MedicalSearchService.init()     # loads 28.5 MB JSON knowledge base
  +-- GemOneApp
        +-- GemmaServiceProvider      # InheritedWidget + ChangeNotifier
              +-- GemmaService        # model lifecycle state machine
                    +-- InferenceChat # per-module chat session
```

State management uses a hand-rolled `InheritedWidget + ChangeNotifier` pattern with no external packages. `GemmaService` drives a `ModelStatus` machine through `idle -> installing -> loading -> ready / error`. All chat modules extend `BaseChatScreen`, a template base class that owns token streaming, tool dispatch, context reset logic, and the input UI. Subclasses supply only their system prompt and accent color.

---

## XML Tool Calling

Gem One teaches Gemma to invoke on-device tools via a plain XML protocol embedded in each module's system prompt - no external function-calling API needed.

**Model emits:**
```xml
<gem_one_call><tool>calculator</tool><expr>12 * (5 + 3)</expr></gem_one_call>
```

**App injects the result as the next user turn:**
```
<tool_response><tool>calculator</tool><result>96</result></tool_response>
Using the tool_response above, give the final answer. Do not emit another tool call.
```

The trailing instruction is critical - without it, Gemma sometimes responds to a result with a second tool call, creating an infinite loop. The loop is also hard-capped at `_maxToolHops = 3`.

During streaming, partial tag prefixes can appear mid-buffer. `ToolParser.trailingPartialOpenLength()` withholds them from the UI until the full tag resolves:

```dart
static int trailingPartialOpenLength(String text) {
  for (int n = openTag.length - 1; n > 0; n--) {
    if (text.length >= n &&
        text.substring(text.length - n) == openTag.substring(0, n)) {
      return n;
    }
  }
  return 0;
}
```

**Available tools** (all pure Dart, zero native dependencies):

| Tool | Function |
|---|---|
| `calculator` | Recursive-descent expression parser |
| `solve` | Linear and quadratic solver, exact symbolic roots |
| `factor` | GCF, LCM, prime factorization |
| `stats` | Mean, median, mode, std dev, range |
| `convert` | SI-anchored unit conversion (length, mass, temp, time, energy) |
| `medical_search` | RAG lookup into the local knowledge base |

---

## Medical RAG *(Beta)*

> **Beta disclaimer:** The RAG pipeline is functional but the knowledge base (`medical_brain.json`) is sourced from MedlinePlus (https://medlineplus.gov/xml.html) and has not been clinically reviewed. It is not intended for real medical diagnosis and always directs users to consult a doctor.

The Medical module runs retrieval-augmented generation over a 28.5 MB local JSON knowledge base bundled as a Flutter asset. On each query, `MedicalSearchService.search()` tokenizes the input, skips tokens under 3 characters, scores every entry by keyword hit count, and injects the top result (capped at 700 characters) into the prompt before it reaches the model:

```dart
final results = MedicalSearchService.instance.search(text);
final ragPrompt = '''
Use the medical information below if relevant.
${ results.join('\n\n') }
Question: $text. Answer briefly and clearly.
''';
await super.sendMessage(text, internalPrompt: ragPrompt);
```

The UI shows only the user's original question; the enriched context is internal. Replies are structured into three sections: *Likely cause(s)*, *What to do now*, and *When to seek care*.

---

## Context Management

The 1024-token window requires active management. Gem One uses four strategies:

- **Turn reset:** After 6 exchanges, a fresh `InferenceChat` opens with the same system prompt re-injected. A banner notifies the user.
- **Degenerate reply detection:** A response under 4 words that is not a valid short answer (`yes`, `no`, `ok`, etc.) triggers an automatic session reset, silently recovering from KV-cache corruption.
- **DocWriter compaction:** After generating a document, the session is replaced with a compact context containing only that document, freeing the full token budget for edits.
- **Scholar local feedback:** Correct quiz answers display a local message without a model call, avoiding spending a turn on a one-word acknowledgment.

---

## Scholar and Language Tutor

Scholar generates structured course plans in a custom XML format parsed into a visual lesson map:

```xml
<gem_course>
  <module id="1"><title>Getting Started</title>
    <lesson id="1.1"><title>Variables</title><desc>Types and assignment</desc></lesson>
  </module>
</gem_course>
```

Each lesson produces markdown-formatted content rendered via `flutter_markdown`, with LaTeX math via `flutter_math_fork`, followed by a multiple-choice quiz parsed from a second XML format. Progress is persisted via `SharedPreferences`.

The Language Tutor generates vocabulary in full native script (kanji+kana, Arabic, Devanagari, Hangul, etc.) rather than romanizations. Fill-in-the-blank exercises show the native script with a phonetic guide underneath. Speech recognition and text-to-speech run entirely on-device via `speech_to_text` and `flutter_tts`.

---

## DocWriter and Vision

DocWriter collects all required details in a single numbered question before generating, so the output never contains placeholder text. If the user attaches images, they are passed via `Message.withImage()` - Gemma 4's vision modality reads them directly with no external OCR step. Generated documents are wrapped in `[DOCUMENT_START]...[DOCUMENT_END]` markers, rendered with full markdown support, and exportable to PDF via the `pdf` and `printing` packages.

---

## Privacy and Testing

- Zero network calls after installation. No analytics, telemetry, or crash reporting.
- No accounts or sign-in required.
- All conversations, documents, and quiz data stay on-device.
- Tested on a Samsung Galaxy S24 Ultra. Performance on lower-end devices has not yet been validated and may vary; hardware optimization is planned for future releases.

---

## Prize Track Alignment

**LiteRT Prize:** The full inference stack runs on LiteRT via `flutter_gemma` - GPU backend, `.litertlm` format, vision via `Message.withImage()`, and streaming via `generateChatResponseAsync()` across all six modules.

**Cactus Prize (Local-First Mobile):** No server, no API key, no fallback cloud path. The app is fully functional with zero connectivity.

**Impact - Digital Equity:** On-device AI removes the infrastructure dependency for users who cannot afford a data plan or live outside network coverage.

**Impact - Education:** Scholar and Language Tutor deliver personalized AI-generated courses, quizzes, and pronunciation practice with no internet required.

**Impact - Health:** The Medical Advisor with offline RAG gives community health workers structured medical reference, privately and on-demand.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3 (Dart) |
| Model | Gemma 4 E4B, quantized LiteRT `.litertlm` |
| Inference | flutter_gemma v0.15.0, LiteRT GPU backend |
| Vision | `Message.withImage()` via flutter_gemma |
| State | `InheritedWidget` + `ChangeNotifier` |
| Persistence | `shared_preferences` |
| Medical RAG | 28.5 MB bundled JSON, MedlinePlus source |
| Math tools | Pure Dart: expression parser, equation solver, unit converter |
| Speech | `speech_to_text` + `flutter_tts` |
| Markdown | `flutter_markdown` + `flutter_math_fork` |
| PDF | `pdf` + `printing` |
