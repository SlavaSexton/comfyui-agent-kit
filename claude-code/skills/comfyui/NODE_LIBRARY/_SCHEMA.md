# Node Library - how it is built and read (Layer 4 reference)

This is the kit's per-node knowledge base, in the spirit of The Foundry's Nuke node reference: for every
node we use or meet, what it is for, what each input and output is for, how it behaves, where it shines, its
bugs and the fixes we know, what it pairs badly with, and where it slots in a graph. The point is to build
workflows AND custom nodes faster, and to decide *build vs search* (write our own node) with confidence.

## Prime directive: discoverability

A future agent must never say "I did not know this existed, I just found it." It must remember WHAT is WHERE.
So:

1. **One front door, always advertised.** `_INDEX.md` is the map of everything documented. `SKILL.md`'s
   routing map points here for ANY node question (I/O, gotchas, placement, build-vs-search). Every agent reads
   SKILL.md, so no agent can plead ignorance.
2. **Predictable paths.** Entries live in category files (`color-and-transform.md`, `samplers.md`,
   `loaders.md`, ...). The index maps node -> category file -> anchor. An agent can guess where a node lives.
3. **Add on encounter (self-healing).** When you use or meet a node that is NOT in the library, add its entry
   before you finish the task. The "did not know" surface shrinks every session. This is a rule, not a nicety.
4. **No orphan knowledge.** Cross-link both ways with `KIJAI.md` (kijai nodes), `NODES.md` (in-graph LLM
   nodes), `KNOWN_ISSUES.md` (live bugs). The library links out; those link back to the index.

## Two laws for every entry

### Law 1 - LIVE vs CURATED (never fabricate I/O)
`/object_info` (MCP `get_node_info`) is the LIVE source of a node's exact inputs, outputs, types, defaults. It
changes between ComfyUI versions. **Do not freeze it here as if permanent, and never write it from memory or
from the node's name.** This library holds the layer `/object_info` cannot give:
- the SEMANTICS of each input/output (what it is FOR, not just its type),
- how the node works, its strengths,
- bugs / lags + fixes, anti-patterns, placement, modification ideas.

Each entry names the I/O it lists as *confirmed via get_node_info on <date>* or marks it *inferred - confirm
via get_node_info*. When in doubt, point the reader at `/object_info` rather than guess.

### Law 2 - confirmed vs inferred + date (Fable / Teaching standard)
Every load-bearing claim is either confirmed (names its evidence: a get_node_info pull, the node's source
file, a workflow that ran) or marked inferred (and says what would confirm it). Date-stamp the entry. Flag
legacy / broken. Never invent a node name, an input name, a setting, or a default.

## Entry template (copy this)

```markdown
### <ClassType>  (display: "<Display Name>")
- **pack / source:** <custom-node pack + install command, or "core ComfyUI"> | <repo link>
- **category:** <ComfyUI menu category> | **I/O confirmed via get_node_info:** <date or "inferred">
- **purpose:** <one or two lines: what it is for>
- **inputs:**
  - `<name>` (`<TYPE>`) - <what it is FOR; gotchas; default if load-bearing>
- **outputs:**
  - `<name>` (`<TYPE>`) - <what it carries; what typically consumes it>
- **how it works:** <the mechanism, briefly>
- **strengths:** <when it is the right choice>
- **bugs / lags + fixes:** <known issues + the fix if we have one; link KNOWN_ISSUES.md> (or "none known")
- **anti-patterns:** <what it pairs badly with, what it cannot do, what is unacceptable to feed it>
- **placement:** <what feeds it / what it feeds; where in a pipeline>
- **author:** <only for nodes WE built: "@author <requester name>, <date>"; else omit>
```

## Custom-node authorship (nodes WE build)

When the decision is *build our own node*, credit the person who requested it:
- `@author <Requester Name>` + date in the node's Python header (e.g. `# @author Slava Sexton, 2026-06-30`),
- a row in `ATTRIBUTION.md`,
- the `author:` field in the library entry.
Each user has their own name; use the name of whoever asked for that node.

## Build vs search (when to write our own node)

Prefer writing a custom node when ALL hold: the need is simple and well-scoped, no clean maintained node
already does it, and it is reusable. Prefer an existing node when a maintained one covers it (do not reinvent;
check KIJAI.md and `search_custom_nodes` first). Record the decision (and why) in the entry. The 9
`comfyui-node-*` skills are the how-to for building; this library is the what/why/where.

## How to add a node (the loop)

1. `get_node_info <ClassType>` -> read the real inputs/outputs/types/defaults.
2. Read the node's source if behavior is non-obvious (do not guess from the name).
3. Fill the template; mark confirmed/inferred + date.
4. Put the entry in the right category file; add its row to `_INDEX.md` (name, one-line purpose, link).
5. Cross-link KNOWN_ISSUES.md if it has a live bug; KIJAI.md if it is a kijai node.
6. Sync the changed file to `~/.claude/skills/comfyui/` per CLAUDE.md.
