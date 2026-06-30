# Utilities and model patches

Small graph-plumbing nodes plus one model-patch apply. The `utilities` family is the wiring layer: constant
sources (the Primitive nodes), a value inspector (`PreviewAny`), arithmetic and type conversion on the numeric
ports (`ComfyMathExpression`, `ComfyNumberConvert`), a boolean branch (`ComfySwitchNode`), and a resolution
calculator (`ResolutionSelector`). None of these touch a diffusion model; they move INT / FLOAT / STRING /
BOOLEAN values around and shape the graph. `SUPIRApply` is the odd one out: a `model/patch` node that wraps a
diffusion `MODEL` with SUPIR restoration control for image upscaling. All I/O below is **confirmed via
get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided slice; display names, pack/module, and the
`experimental` flag were read live the same day. The semantics, placement, and gotchas are the curated layer.
Every node here is core ComfyUI shipped under a `comfy_extras.*` module, not a custom pack. Any input typed
`COMBO` of file names would be one machine's installed files; none of these have one. Order is by how often you
reach for them.

---

### PrimitiveInt  (display: "Int")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_primitive`) | **category:** `utilities/primitive` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** emit a single integer constant onto the graph so one value can drive several inputs from one place.
- **inputs:**
  - `value` (`INT`) - the integer to output. The widget carries `control_after_generate` (fixed by default), the same per-run increment / randomize control seen on seeds, so this node can also act as a counter or seed source.
- **outputs:**
  - `INT` (`INT`) - the integer; feeds any `INT` port (steps, width, height, batch_size, seed, a `multiple`, and so on).
- **how it works:** a passthrough constant. Whatever is in the widget is the output, with the optional after-generate behavior applied between runs.
- **strengths:** one source of truth for a number you wire to many nodes; edit it once and every consumer updates. The after-generate control makes it a lightweight seed or counter without a dedicated node.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** do not use it to carry a float; fractional values get an `INT` port and are truncated. Use `PrimitiveFloat` for cfg, denoise, strengths, and other fractional values.
- **placement:** a leaf at the edge of the graph. Nothing feeds it; it feeds `INT` consumers. Reach for it when the same number must be shared, otherwise type the value directly on the consumer's widget.

### PrimitiveFloat  (display: "Float")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_primitive`) | **category:** `utilities/primitive` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** emit a single floating-point constant onto the graph, for the fractional values an `INT` source cannot carry.
- **inputs:**
  - `value` (`FLOAT`) - the float to output (cfg, denoise, a LoRA strength, a SUPIR strength, megapixels, and the like).
- **outputs:**
  - `FLOAT` (`FLOAT`) - the float; feeds any `FLOAT` port.
- **how it works:** a passthrough constant; the widget value is the output.
- **strengths:** one shared source for a fractional parameter you sweep across several nodes; change it once and all consumers follow.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** wiring its `FLOAT` into an `INT`-only port (it will not connect cleanly, or the consumer truncates). Use `PrimitiveInt` for whole numbers. For converting between the two at runtime, use `ComfyNumberConvert`.
- **placement:** a leaf feeding `FLOAT` consumers. Nothing feeds it.

### PrimitiveString  (display: "Text String")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_primitive`) | **category:** `utilities/primitive` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** emit a single-line string constant, for short text reused across the graph (a filename prefix, a token, a short label).
- **inputs:**
  - `value` (`STRING`, single-line) - the text to output. Single-line widget; for long multi-line prompts use `PrimitiveStringMultiline`.
- **outputs:**
  - `STRING` (`STRING`) - the text; feeds any `STRING` port (a `filename_prefix`, a path fragment, a node that takes a short string).
- **how it works:** a passthrough constant; the widget text is the output.
- **strengths:** one shared source for a piece of text wired to several nodes; edit once.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using the single-line node for a long prompt with line breaks; the widget is single-line. For prompts and any multi-line text, use `PrimitiveStringMultiline`. This is a plain string, not encoded conditioning; it does not replace `CLIPTextEncode`.
- **placement:** a leaf feeding `STRING` consumers. Nothing feeds it.

### PrimitiveStringMultiline  (display: "Text String (Multiline)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_primitive`) | **category:** `utilities/primitive` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** emit a multi-line string constant, the usual way to hold a prompt as text and feed it to one or more encoders.
- **inputs:**
  - `value` (`STRING`, multiline) - the text to output. Multi-line widget, so it holds full prompts with line breaks.
- **outputs:**
  - `STRING` (`STRING`) - the text; commonly wired into the `text` input of `CLIPTextEncode` (or a model-specific encoder), or any `STRING` consumer.
- **how it works:** a passthrough constant; the multi-line widget text is the output.
- **strengths:** keeps a prompt in one node you can wire to several encoders (positive into one, a shared fragment into others), so the prompt lives in one place. Lives under the "Basics" essentials category.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** treating its `STRING` as conditioning; it is raw text and still needs an encoder (`CLIPTextEncode` or the model's own) before a sampler can use it. Wiring it straight into `KSampler.positive` is a type mismatch.
- **placement:** a leaf feeding `STRING` consumers, most often a text-encode node ahead of the sampler.

### PrimitiveBoolean  (display: "Boolean")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_primitive`) | **category:** `utilities/primitive` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** emit a single true/false constant, typically to drive a toggle or the selector of a switch node.
- **inputs:**
  - `value` (`BOOLEAN`) - the boolean to output.
- **outputs:**
  - `BOOLEAN` (`BOOLEAN`) - the flag; feeds any `BOOLEAN` port, including `ComfySwitchNode.switch`.
- **how it works:** a passthrough constant; the widget toggle is the output.
- **strengths:** one shared on/off source for several toggles at once; pairs naturally with `ComfySwitchNode` to pick between two branches from a single control.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** expecting it to gate execution by itself; a bare boolean only carries a value. To actually choose between two upstream branches you still need `ComfySwitchNode` (or another node that consumes the flag).
- **placement:** a leaf feeding `BOOLEAN` consumers. Nothing feeds it.

### PreviewAny  (display: "Preview as Text")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_preview_any`) | **category:** `utilities` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** show the value on ANY wire as text in the UI, the universal debug / inspect probe for non-image data.
- **inputs:**
  - `source` (`*`) - a wildcard input that accepts any type (INT, FLOAT, STRING, BOOLEAN, a list, a dict-like value, and so on). It stringifies whatever it receives.
- **outputs:**
  - `STRING` (`STRING`) - the stringified value, so you can both display it and pass it on to a `STRING` consumer. This is an output node: it renders the text in the node body when the graph runs.
- **how it works:** an output node (`output_node: true`) that converts the incoming value to a string, displays it in the UI, and also returns it as `STRING`. It does not alter the upstream graph; it taps a wire.
- **strengths:** the fastest way to see what a numeric / string / boolean wire actually carries at runtime, without saving a file. Accepts anything via the `*` input, so one node debugs any port. Useful for confirming a `ComfyMathExpression` result or a converted number.
- **bugs / lags + fixes:** none known. For image data you want a visual preview, not text; use `PreviewImage` instead (this stringifies, it does not render pixels).
- **anti-patterns:** using it to "preview" an image, latent, or other binary tensor expecting to SEE it; you get a string representation, not the picture. For images use `PreviewImage`; for audio `PreviewAudio`. Leaving many of these wired in a production graph adds clutter; it is a debug aid.
- **placement:** a tap anywhere you want to read a value. Hang it off any output port; it is terminal for display but its `STRING` can also continue downstream.

### ResolutionSelector  (display: "Resolution Selector")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_resolution`) | **category:** `utilities` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** compute `width` and `height` from an aspect ratio and a megapixel target, so `EmptyLatentImage` (and similar) get correctly sized, model-friendly dimensions without hand math.
- **inputs:**
  - `aspect_ratio` (`COMBO`) - a fixed dropdown of named ratios (square, portrait, photo, widescreen, ultrawide, and so on). Default is the square option. The list is built into the node, not read from disk.
  - `megapixels` (`FLOAT`, default 1.0, range 0.1 to 16) - the total pixel budget. 1.0 MP is about a 1024x1024 square; raise it for higher-resolution canvases (within what the model handles).
  - `multiple` (`INT`, default 8, range 8 to 128, step 4) - rounds each side to the nearest multiple of this value. 8 suits SD-family latents (the 8x VAE downscale); some models want 16 or 64. Marked advanced in the UI.
- **outputs:**
  - `width` (`INT`) - the computed width, already rounded to `multiple`; feeds `EmptyLatentImage.width` (or any `INT` size port).
  - `height` (`INT`) - the computed height, already rounded to `multiple`; feeds `EmptyLatentImage.height`.
- **how it works:** picks the side ratio for the chosen aspect, solves the two sides so their product is near the megapixel target, then snaps each side to the nearest multiple of `multiple`. Output is the snapped width and height in pixels.
- **strengths:** removes the arithmetic and the "is this divisible by 8" guesswork; one node sets both sides of the latent from a ratio and a pixel budget. Swapping aspect or megapixels rewires nothing downstream.
- **bugs / lags + fixes:** none known. Because each side is snapped independently to `multiple`, the realized total can land slightly off the exact megapixel target and the ratio can shift a hair; that is rounding, not a defect.
- **anti-patterns:** pushing `megapixels` far past what the model was trained for (for example a large square on SD1.5) gives duplicated or warped subjects; the node will happily compute an off-native size. Setting `multiple` to a value the model's latent does not like (not a multiple of its VAE factor) can error at the latent node. This sizes a canvas; it does not resize an existing image (use an image-resize / upscale node for that).
- **placement:** a leaf feeding the size inputs of `EmptyLatentImage` (or another node that takes width/height). Sits at the front of the graph, before sampling.

### ComfyNumberConvert  (display: "Convert Number")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_number_convert`) | **category:** `utilities` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** take a value and hand back both its FLOAT and its INT form, so you can bridge a numeric (or numeric-looking string / boolean) value into whichever numeric port a consumer wants.
- **inputs:**
  - `value` (`INT,FLOAT,STRING,BOOLEAN`) - a multi-type input that accepts an int, a float, a numeric string, or a boolean. It is parsed to a number, then offered in both numeric forms.
- **outputs:**
  - `FLOAT` (`FLOAT`) - the value as a float; feeds a `FLOAT` port.
  - `INT` (`INT`) - the value as an integer; feeds an `INT` port. Float-to-int here drops the fractional part (rounds toward / truncates per the node's implementation), so expect a whole number out of the `INT` port.
- **how it works:** parses the incoming value (a string is read as a number, a boolean as 0 / 1) and returns the same magnitude in both numeric types at once. You wire whichever output the downstream port needs.
- **strengths:** the clean fix for a FLOAT-into-INT (or INT-into-FLOAT) mismatch between two nodes, and for turning a numeric string into a usable number. One node covers all four input forms.
- **bugs / lags + fixes:** none known. The `INT` output loses the fraction; if you need the precise fractional value, take the `FLOAT` output instead.
- **anti-patterns:** feeding a non-numeric string (text that is not a number) and expecting a sensible number out; it parses numbers, not arbitrary text. Reaching for it to convert a non-numeric type (an IMAGE, a LATENT); it works on numeric / numeric-string / boolean values only.
- **placement:** an inline adapter on a value line, between a producer whose type does not match the consumer's port. Often sits after `PrimitiveFloat` / `PrimitiveInt` or a node that emits the wrong numeric type.

### ComfyMathExpression  (display: "Math Expression")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_math`) | **category:** `utilities` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** evaluate a math expression over named operand inputs and return the result as FLOAT, INT, and BOOL at once, for computed sizes, scaled strengths, derived step counts, and similar in-graph arithmetic.
- **inputs:**
  - `expression` (`STRING`, multiline, default `a + b`) - the formula to evaluate, written in terms of the operand names. Default uses the first two operands.
  - `values` (`COMFY_AUTOGROW_V3`) - an autogrowing set of operand slots named `a`, `b`, `c`, ... up to `z` (minimum one). Each slot is typed `FLOAT,INT,BOOLEAN`, so you wire numbers or booleans in and reference them by their single letter in the expression. Add only as many operands as the formula uses.
- **outputs:**
  - `FLOAT` (`FLOAT`) - the result as a float.
  - `INT` (`INT`) - the result as an integer (the float result coerced to int; a fractional result is rounded / truncated per the node).
  - `BOOL` (`BOOLEAN`) - the result interpreted as a boolean (the output port is named `BOOL`; its type is `BOOLEAN`). Useful when the expression is a comparison.
- **how it works:** parses the expression, substitutes the wired operand values by name, evaluates it, and exposes the single result in all three return types so you wire whichever the consumer needs.
- **strengths:** does in one node what would otherwise be a chain of add / multiply / convert nodes; named operands keep a multi-term formula readable; one result available as float, int, or bool removes a separate convert step. The autogrow input means you only expose the operands you actually use.
- **bugs / lags + fixes:** none known. The `INT` output rounds the result; for an exact fractional value read the `FLOAT` output. Referencing an operand letter in the expression that you have not added as a slot will fail to evaluate; add the slot first.
- **anti-patterns:** writing an expression over operands that are not wired (a name with no slot), or expecting non-numeric operations; the operands are numeric / boolean. Using it where a single passthrough constant would do (just use a Primitive). It computes scalars, not tensors; it does not operate on IMAGE / LATENT data.
- **placement:** an inline compute node on a value line. Operands come from Primitive nodes, other computed values, or node outputs; the chosen result output feeds the consumer (a size port, a strength, a step count). `PreviewAny` on an output is the quick way to verify the formula.

### ComfySwitchNode  (display: "Switch")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_logic`) | **category:** `utilities/logic` | **I/O confirmed via get_node_info:** 2026-06-30 | **experimental** (flagged experimental in the live schema)
- **purpose:** pick one of two inputs to pass through, chosen by a boolean, so a single flag routes the graph down one of two branches.
- **inputs:**
  - `switch` (`BOOLEAN`) - the selector. False forwards `on_false`, true forwards `on_true`. Drive it from `PrimitiveBoolean` or any boolean producer.
  - `on_false` (`COMFY_MATCHTYPE_V3`) - the value passed through when `switch` is false. Type-matched: it adopts whatever type you wire in, and the output matches it. This input is lazy.
  - `on_true` (`COMFY_MATCHTYPE_V3`) - the value passed through when `switch` is true. Same type-matching; also lazy.
- **outputs:**
  - `output` (`COMFY_MATCHTYPE_V3`) - the selected branch's value, carrying the matched type (the output's type follows the connected inputs, template id `switch`). Feeds whatever consumes that type.
- **how it works:** a match-type, lazy router. The two branch inputs share a type template, so the node adopts the wired type and its output is that same type. Because the branch inputs are lazy, only the selected branch is actually evaluated: a false `switch` skips computing whatever feeds `on_true`, and vice versa. That makes the switch a real execution gate, not just a value picker, so you can branch around an expensive subgraph.
- **strengths:** one boolean chooses between two pipelines and the unchosen branch is not executed (lazy), which saves the cost of the skipped side. Type-agnostic via match-type, so it routes any single type (IMAGE, LATENT, MODEL, CONDITIONING, a number) without a per-type variant.
- **bugs / lags + fixes:** none known. It is flagged `experimental` in the schema, so its exact behavior may shift between ComfyUI versions; re-confirm with `get_node_info` if a graph that uses it misbehaves after an update.
- **anti-patterns:** wiring the two branches with mismatched types and expecting a clean pass; match-type wants both branches to agree on the type it forwards. Expecting it to merge or blend the two inputs; it selects one, it does not combine them. Using it where both branches must always run anyway (then the lazy skip buys nothing and you have only added a hop).
- **placement:** on any line where one boolean should choose between two upstream branches. `switch` comes from a boolean source; `on_false` / `on_true` come from the two candidate subgraphs; `output` feeds the shared downstream consumer.

### SUPIRApply  (display: "SUPIRApply")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_model_patch`) | **category:** `model/patch/supir` | **I/O confirmed via get_node_info:** 2026-06-30 | **experimental** (flagged experimental in the live schema)
- **purpose:** wrap a diffusion `MODEL` with the SUPIR restoration patch for image upscaling / restoration, applying a `MODEL_PATCH` and an input image so the sampler restores toward that image with controllable strength and fidelity.
- **note on source:** this is ComfyUI's BUILT-IN SUPIR apply (module `comfy_extras.nodes_model_patch`, `display_name` not set so the UI shows the class name `SUPIRApply`). It is NOT the separate kijai SUPIR custom pack (`ComfyUI-SUPIR`), which has its own differently-named nodes and a different I/O surface. Do not assume kijai SUPIR docs / parameters apply here; confirm against this node's own schema.
- **inputs:**
  - `model` (`MODEL`) - the base diffusion model to patch. The node returns a wrapped `MODEL`, it does not run sampling itself.
  - `model_patch` (`MODEL_PATCH`) - the SUPIR patch weights to apply (loaded by the matching model-patch loader for SUPIR). This is the control side of the restoration.
  - `vae` (`VAE`) - the autoencoder, needed because the patch works with the input image's latent representation.
  - `image` (`IMAGE`) - the source image to restore / upscale toward; the restoration is conditioned on it.
  - `strength_start` (`FLOAT`, default 1.0, range 0 to 10) - control strength at the START of sampling (high sigma). Sets how hard the patch steers early in the denoise.
  - `strength_end` (`FLOAT`, default 1.0, range 0 to 10) - control strength at the END of sampling (low sigma), linearly interpolated from `strength_start`. Lets the control fade or grow across the schedule.
  - `restore_cfg` (`FLOAT`, default 4.0, range 0 to 20, advanced) - pulls the denoised output back toward the input latent; higher means stronger fidelity to the input, 0 disables the restore pull. Trades detail / creativity against faithfulness to the source.
  - `restore_cfg_s_tmin` (`FLOAT`, default 0.05, range 0 to 1, advanced) - the sigma threshold below which `restore_cfg` is switched off, so the restore pull only acts above this noise level.
- **outputs:**
  - `MODEL` (`MODEL`) - the SUPIR-patched diffusion model; wire it into the sampler in place of the original `MODEL`. Sampling that model performs the SUPIR-controlled restoration.
- **how it works:** attaches the SUPIR `MODEL_PATCH` to the diffusion model and bakes in the restoration controls (start/end strength, the restore-cfg pull and its sigma cutoff) along with the input image and VAE. The returned `MODEL` carries this behavior; the actual restoration happens when a sampler runs that model over a latent derived from the image.
- **strengths:** brings SUPIR-style restoration into a standard ComfyUI sampling graph as a model wrapper, with explicit, separately tunable control over how strongly and how faithfully it restores across the denoise (start vs end strength, the restore pull, and where that pull stops). Being core, it needs no third-party pack installed.
- **bugs / lags + fixes:** none known specific to the node. It is flagged `experimental`, so parameters and behavior may change between ComfyUI versions; re-confirm with `get_node_info` before relying on exact defaults. SUPIR restoration is VRAM-heavy at high resolution, but that cost is in the sampling pass over the patched model, not in this apply node.
- **anti-patterns:** feeding a `MODEL_PATCH` that is not a SUPIR patch, or a `model` of a family the patch was not built for; the patch and base must match. Confusing it with the kijai `ComfyUI-SUPIR` pack and pulling parameters from that node's docs (different node, different I/O). Treating its output as a finished image; it returns a patched `MODEL` that still must be sampled and decoded. Pushing `strength_start` / `strength_end` very high while also forcing high `restore_cfg` can over-constrain the result toward the input and kill the added detail; balance the two.
- **placement:** on the `MODEL` line, between the model loader and the sampler, in an image-restoration / upscaling graph. It needs an `IMAGE` (the source), a `VAE`, and a SUPIR `MODEL_PATCH` wired in; its `MODEL` output feeds the sampler, whose latent comes from the same input image.
