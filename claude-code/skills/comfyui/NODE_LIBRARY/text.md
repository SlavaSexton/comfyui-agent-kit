# Text

The `text` category: core ComfyUI nodes that operate on STRING values inside a graph. Five are pure string utilities (concatenate, find/replace, regex replace, regex extract, JSON field pluck) that live in `comfy_extras.nodes_string`; they are the glue that shapes a prompt, parses an LLM reply, or builds a filename token. The sixth, `TextGenerate`, is a different animal: a local in-graph LLM / VLM text generator (`comfy_extras.nodes_textgen`) that runs a multimodal model loaded as a `CLIP` object and emits text. The string utilities cost almost nothing; `TextGenerate` loads and runs a language model. All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided slice; display names, module paths, and the `mode` / `sampling_mode` option lists were confirmed by a live `get_node_info` pull the same day. The semantics, placement, and gotchas are the curated layer. None of these nodes is an output node, and none is an API / cloud node (`api_node: false` on all six). Entries are ordered most-used utility first, with the LLM node last because it belongs to a separate family.

---

### StringConcatenate  (display: "Concatenate Text")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_string`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** join two strings into one, with an optional separator between them.
- **inputs:**
  - `string_a` (`STRING`) - the first piece (multiline). The left side of the join.
  - `string_b` (`STRING`) - the second piece (multiline). The right side of the join.
  - `delimiter` (`STRING`) - what to place between `a` and `b`. Default is an empty string, so by default the two are glued with nothing between them. Set it to a space, a comma, `, `, or a newline when you need separation.
- **outputs:**
  - `STRING` (`STRING`) - the concatenated result; feeds any STRING consumer (a text-encode node's `text`, another string utility, a filename prefix).
- **how it works:** returns `string_a + delimiter + string_b`. No trimming, no smart spacing; what you pass is what gets joined.
- **strengths:** the simplest way to stitch a base prompt to a style suffix, or a directory token to a name, without leaving the graph. Chains: feed its output into another `StringConcatenate` to assemble three or more pieces.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** expecting it to insert a space automatically; if you do not set `delimiter`, the strings run together (`redcar` not `red car`). Only two inputs per node, so building a long sentence means chaining several nodes; for many fragments a single multiline `STRING` widget or a `TextGenerate` is cleaner. It does no formatting or templating (no `{}` substitution); it concatenates literally.
- **placement:** mid-graph on the STRING line, before a text-encode node or another string utility. Anything producing a STRING can feed either input.

### StringReplace  (display: "Replace Text")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_string`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** plain (non-regex) find-and-replace on a string.
- **inputs:**
  - `string` (`STRING`) - the text to operate on (multiline).
  - `find` (`STRING`) - the literal substring to look for (multiline). Treated as a literal, not a pattern; special characters match themselves.
  - `replace` (`STRING`) - the literal text to substitute in for every occurrence of `find` (multiline).
- **outputs:**
  - `STRING` (`STRING`) - the text with all matches replaced; feeds any STRING consumer.
- **how it works:** a literal string replace of every occurrence of `find` with `replace`. No pattern matching, no capture groups.
- **strengths:** the right tool when you know the exact text to swap (strip a known token, swap a placeholder for a value, delete a phrase by replacing it with an empty string). Predictable because nothing is interpreted as a pattern.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** reaching for it when you need a pattern (variable text, anchors, alternation, case-insensitivity); use `RegexReplace` for that. It replaces ALL occurrences with no count limit and no case option, so it cannot do "first only" or case-insensitive matching; `RegexReplace` exposes both. An empty `find` is a no-op rather than an insert.
- **placement:** mid-graph on the STRING line, typically to clean a prompt or an LLM reply before it is consumed.

### RegexReplace  (display: "Replace Text (Regex)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_string`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** find and replace text using a regular expression (the node's own description: "Find and replace text using regex patterns").
- **inputs:**
  - `string` (`STRING`, required) - the text to operate on (multiline).
  - `regex_pattern` (`STRING`, required) - the regex to match (multiline). Standard Python `re` syntax. Backreferences in `replace` use `\1`, `\g<name>` for named groups.
  - `replace` (`STRING`, required) - the replacement template (multiline); may reference capture groups.
  - `case_insensitive` (`BOOLEAN`, optional, default True) - when on, matching ignores case. Note the default is True here, the opposite of a bare `re` call, so a pattern you expect to be case-sensitive will not be unless you turn this off.
  - `multiline` (`BOOLEAN`, optional, default False) - when on, `^` and `$` match at every line boundary, not just the start and end of the whole string (the `re.MULTILINE` flag).
  - `dotall` (`BOOLEAN`, optional, default False) - when on, `.` matches newline characters too; when off, `.` stops at a newline (the `re.DOTALL` flag). Confirmed by the node's own tooltip.
  - `count` (`INT`, optional, default 0, min 0 max 100) - maximum replacements. 0 means replace all occurrences (the default); 1 replaces only the first match, 2 the first two, and so on. Confirmed by the node's own tooltip.
- **outputs:**
  - `STRING` (`STRING`) - the text after substitution; feeds any STRING consumer.
- **how it works:** compiles `regex_pattern` with the chosen flags and runs a substitution against `string`, replacing up to `count` matches (all if 0) with `replace`, capture-group references expanded.
- **strengths:** the full-power replace: anchors, alternation, capture-group rewriting, case control, line-boundary control, and a replacement cap in one node. Use it to reformat structured text, strip a class of tokens, or rewrite matches by group.
- **bugs / lags + fixes:** none known in the node. The behavioral trap is the `case_insensitive` default of True (see inputs); a malformed `regex_pattern` raises at run time the way any bad regex does, that is a pattern error, not a node bug.
- **anti-patterns:** using it for a literal swap where `StringReplace` is simpler and cannot misfire on regex metacharacters (a `.` or `(` in your search text is a pattern in `RegexReplace`, a literal in `StringReplace`). Forgetting the True default on `case_insensitive` when you need exact-case matching. Expecting `^`/`$` to span lines without enabling `multiline`, or `.` to cross newlines without `dotall`.
- **placement:** mid-graph on the STRING line. Common upstream is an LLM reply or a raw prompt; common downstream is a text-encode node, a filename token, or `RegexExtract` / `JsonExtractString`.

### RegexExtract  (display: "Extract Text")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_string`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** pull a substring (or a capture group, or all matches) out of a string using a regular expression.
- **inputs:**
  - `string` (`STRING`, required) - the text to search (multiline).
  - `regex_pattern` (`STRING`, required) - the regex to apply (multiline), standard Python `re` syntax.
  - `mode` (`COMBO`, required) - what to return. Options confirmed live 2026-06-30: `First Match`, `All Matches`, `First Group`, `All Groups`. "Match" returns the whole matched span; "Group" returns a capture group (which group is set by `group_index`); "First" returns one, "All" returns every hit (joined into the single STRING output).
  - `case_insensitive` (`BOOLEAN`, required, default True) - ignore case when matching. Default True, same gotcha as `RegexReplace`.
  - `multiline` (`BOOLEAN`, required, default False) - `^`/`$` match at line boundaries (`re.MULTILINE`).
  - `dotall` (`BOOLEAN`, required, default False) - `.` matches newlines (`re.DOTALL`).
  - `group_index` (`INT`, required, default 1, min 0 max 100) - which capture group the "Group" modes return. 1 is the first parenthesized group; 0 is the whole match. Only meaningful in `First Group` / `All Groups` mode.
- **outputs:**
  - `STRING` (`STRING`) - the extracted text (a single match/group, or all of them combined); feeds any STRING consumer.
- **how it works:** compiles the pattern with the chosen flags, runs it against `string`, and returns the piece selected by `mode` (and `group_index` for the group modes). The single STRING output means "All" modes are returned as a combined string, not a list.
- **strengths:** the parser for getting a clean value out of messy text, the first sentence, a quoted span, a tagged field, a number, the contents of a capture group. Pairs naturally after an LLM step that returns prose you need to reduce to one value.
- **bugs / lags + fixes:** none known in the node. Watch two things: the `case_insensitive` True default, and `mode` versus `group_index`, setting a `group_index` does nothing unless `mode` is a "Group" mode.
- **anti-patterns:** picking a "Group" mode with a pattern that has no capture groups (nothing to return), or a "Match" mode while expecting a specific group (the whole span comes back instead). Treating the output of an "All" mode as a structured list; it is one combined STRING. For pulling a value out of JSON specifically, `JsonExtractString` is more robust than hand-writing a regex.
- **placement:** mid-graph on the STRING line, usually downstream of a text source (an LLM reply, a loaded text file) and upstream of whatever consumes the extracted value.

### JsonExtractString  (display: "Extract Text from JSON")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_string`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** read one value out of a JSON string by key, returning it as a STRING.
- **inputs:**
  - `json_string` (`STRING`) - the JSON document as text (multiline). It must be a parseable JSON string, not an already-decoded object (there is no JSON type in the graph; JSON travels as STRING).
  - `key` (`STRING`) - the key to look up (single line). Confirmed via get_node_info as a plain STRING key input; the exact lookup semantics (whether it supports nested or dotted paths versus a single top-level key) are not specified by the I/O alone and the node carries no tooltip. Treat single top-level key lookup as the confirmed case; for nested access, read the node source or test rather than assume a path syntax. *(inferred for nested keys, confirm via the node source or a test run.)*
- **outputs:**
  - `STRING` (`STRING`) - the value found at `key`, as text; feeds any STRING consumer.
- **how it works:** parses `json_string` as JSON and returns the value at `key` coerced to a string. The output is always STRING, so a numeric or boolean JSON value comes back as its text form.
- **strengths:** the clean way to consume a JSON reply from an LLM or an API-node step, pluck the one field you need (a caption, a prompt, a label) without writing a regex against the JSON. More robust than `RegexExtract` for structured data because it actually parses rather than pattern-matches.
- **bugs / lags + fixes:** none known. Malformed JSON in `json_string`, or a missing `key`, will fail or return empty the way a JSON lookup does; that is input shape, not a node bug. Whether nested-key access is supported is unconfirmed (see inputs).
- **anti-patterns:** feeding it text that is not valid JSON (use `RegexExtract` for free-form prose). Assuming a dotted / nested path works before confirming it. Expecting a non-string type out; everything comes back as STRING.
- **placement:** mid-graph on the STRING line, typically right after a node that emits JSON (an LLM or API node configured to return JSON) and before the consumer of the extracted field.

### TextGenerate  (display: "Generate Text")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_textgen`) | **category:** `text` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** run a local LLM / VLM inside the graph and return generated text. It takes a multimodal language model (loaded and passed on the `CLIP` input), a prompt, and optional image / video / audio context, and emits a STRING. Confirmed core, not an API node (`api_node: false`); the node's own search aliases are `LLM` and `gemma`, and it lives in `comfy_extras.nodes_textgen`.
- **inputs:**
  - `clip` (`CLIP`, required) - the language model to run. This is the load-bearing subtlety: the model is carried on a `CLIP`-typed port, but it is NOT the checkpoint's text-encoder CLIP and it does NOT come from `CLIPTextEncode`'s world. It is a multimodal LLM (Gemma-class, per the aliases) loaded as a CLIP object by the appropriate loader. Wiring a normal SD/SDXL text-encoder CLIP here is the classic mistake.
  - `prompt` (`STRING`, required, multiline, dynamicPrompts on) - the instruction / user text for the model.
  - `max_length` (`INT`, required, default 256, min 1 max 2048) - maximum tokens to generate. Higher is slower and uses more memory.
  - `sampling_mode` (`COMFY_DYNAMICCOMBO_V3`, required) - a dynamic combo with two keys, `on` and `off` (confirmed live 2026-06-30). With `off`, the node samples greedily / deterministically with no extra knobs. With `on`, it reveals the sampling controls: `temperature` (default 0.7), `top_k` (default 64), `top_p` (default 0.95), `min_p` (default 0.05), `repetition_penalty` (default 1.05), `seed` (default 0), and optional `presence_penalty` (default 0). These appear only when the mode is `on`; the slice lists `sampling_mode` itself, the sub-inputs are the dynamic-combo branch.
  - `image` (`IMAGE`, optional) - a still image for vision context (VLM use).
  - `video` (`IMAGE`, optional) - video frames as an image batch. Per the node tooltip, frames are assumed 24 FPS and subsampled to 1 FPS internally, so a long clip is heavily downsampled before the model sees it.
  - `audio` (`AUDIO`, optional) - an audio clip for audio-aware models.
  - `thinking` (`BOOLEAN`, optional, default False) - operate in thinking mode if the model supports it (node tooltip). No effect on models without a thinking mode.
  - `use_default_template` (`BOOLEAN`, optional, default True) - use the model's built-in system prompt / chat template if it has one (node tooltip). On by default; turn off to send the raw prompt without the model's wrapper.
- **outputs:**
  - `generated_text` (`STRING`) - the model's reply; feeds any STRING consumer (a text-encode node's prompt, a filename token, or a parser like `RegexExtract` / `JsonExtractString`).
- **how it works:** runs the model passed on `clip` over `prompt` plus any image / video / audio context, generating up to `max_length` tokens under the chosen sampling mode, and returns the text. The CLIP-typed model port is what lets a multimodal LLM be loaded and wired like any other model object.
- **strengths:** local, in-graph prompt enrichment / captioning / vision QA with no API key and no network, the offline counterpart to the API LLM nodes in `NODES.md`. Multimodal in one node (text, image, video, audio). Full sampling control when `sampling_mode` is `on`, including a seed for reproducibility. A sibling node `TextGenerateLTX2Prompt` (display "Generate LTX2 Prompt", same module and I/O shape, confirmed live 2026-06-30) specializes the same mechanism for writing LTX2 video prompts.
- **bugs / lags + fixes:** none known in the node. Practical gotchas: it loads and runs an LLM, so it is far heavier than the string utilities and competes for VRAM (coordinate placement on multi-GPU rigs, and with any other model in the graph or with a co-resident Ollama). The 24 FPS to 1 FPS video subsampling means fine temporal detail is lost before generation. Output quality and whether `thinking` / `use_default_template` do anything depend entirely on the specific model loaded on `clip`.
- **anti-patterns:** feeding the checkpoint's text-encoder `CLIP` (or a `CLIPLoader` text encoder) into the `clip` port; this port wants a multimodal LLM loaded as a CLIP object, not an SD text encoder, and the mismatch is the most likely failure. Using it WITH the agent in the loop when you could just write the prompt yourself (per `NODES.md`: the agent's own prompt beats the node templates and is free); reach for an in-graph LLM only when the graph runs unattended. Expecting cheap, instant output, it is a model inference step, not a string op. Passing a long video and assuming full-frame-rate analysis (it is subsampled to 1 FPS).
- **placement:** a model-bearing step on the STRING line. Upstream is the loader that produces the multimodal LLM on a `CLIP` port (plus any IMAGE / video / AUDIO context source); downstream is whatever consumes the generated STRING, commonly a text-encode node for the next generation stage, or a parser (`RegexExtract`, `JsonExtractString`) to reduce the reply to one value. Cross-reference: `docs/NODES.md` covers the API / cloud in-graph LLM nodes (Anthropic Claude, OpenRouter); this is the local-model member of that family.
