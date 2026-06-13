#!/usr/bin/env python
# Distiller + metrics for Claude Code transcripts.
# Usage:
#   py fable_distill.py digest   <transcript.jsonl> [model_filter]   -> per-turn digest (thinking/tools/text)
#   py fable_distill.py metrics  <transcript.jsonl> [...more files]   -> aggregate behavioral metrics per model
#   py fable_distill.py prompts  <transcript.jsonl>                   -> real user prompts only
import json, sys, statistics, collections, os, re
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

def iter_records(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except Exception:
                continue

def tool_sig(b):
    name = b.get("name", "?")
    inp = b.get("input", {}) or {}
    def g(k):
        v = inp.get(k)
        return v if isinstance(v, str) else None
    if name in ("Edit",):
        return f"Edit {g('file_path')}"
    if name == "Write":
        c = inp.get("content") or ""
        return f"Write {g('file_path')} ({len(c)}c)"
    if name == "Read":
        return f"Read {g('file_path')}"
    if name in ("Bash", "PowerShell"):
        d = g("description") or (g("command") or "")[:80]
        return f"{name} :: {d}"
    if name == "Grep":
        return f"Grep /{g('pattern')}/"
    if name == "Glob":
        return f"Glob {g('pattern')}"
    if name in ("Agent",):
        return f"Agent[{g('subagent_type') or '?'}] {g('description')}"
    if name == "Workflow":
        scr = inp.get("script") or ""
        m = re.search(r"name:\s*['\"]([^'\"]+)['\"]", scr)
        nm = m.group(1) if m else (g("name") or "scriptPath")
        return f"Workflow {nm}"
    if name == "TodoWrite":
        todos = inp.get("todos") or []
        return f"TodoWrite ({len(todos)} items)"
    if name == "Task" or name.startswith("Task"):
        return f"{name} {g('description') or ''}"
    if name.startswith("mcp__"):
        return name
    if name == "AskUserQuestion":
        qs = inp.get("questions") or []
        return f"AskUserQuestion ({len(qs)}q)"
    return name

def digest(path, model_filter=None):
    turn = 0
    for r in iter_records(path):
        t = r.get("type")
        msg = r.get("message") or {}
        if t == "user":
            c = msg.get("content")
            # only real user text (skip tool_result-only user records)
            if isinstance(c, str) and c.strip():
                print(f"\n#### USER: {c.strip()[:1500]}")
            elif isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip():
                        print(f"\n#### USER: {b['text'].strip()[:1500]}")
        elif t == "assistant":
            model = msg.get("model")
            if model_filter and model != model_filter:
                continue
            c = msg.get("content") or []
            if not isinstance(c, list):
                continue
            turn += 1
            think = []
            tools = []
            text = []
            for b in c:
                if not isinstance(b, dict):
                    continue
                bt = b.get("type")
                if bt == "thinking":
                    think.append(b.get("thinking", ""))
                elif bt == "tool_use":
                    tools.append(tool_sig(b))
                elif bt == "text":
                    text.append(b.get("text", ""))
            print(f"\n=== TURN {turn} [{model}] ===")
            if think:
                tx = "\n".join(think).strip()
                print(f"[THINK {len(tx)}c]\n{tx[:4000]}")
            if text:
                tt = "\n".join(text).strip()
                if tt:
                    print(f"[SAY]\n{tt[:1500]}")
            if tools:
                print(f"[TOOLS x{len(tools)}] " + " | ".join(tools))

def metrics(paths):
    # per-model aggregate
    M = collections.defaultdict(lambda: {
        "asst_turns": 0, "tool_uses": 0, "think_blocks": 0,
        "think_chars": [], "tools_per_turn": [], "say_chars": [],
        "toolhist": collections.Counter(), "turns_with_tools": 0,
        "turns_with_think": 0,
    })
    for path in paths:
        for r in iter_records(path):
            if r.get("type") != "assistant":
                continue
            msg = r.get("message") or {}
            model = msg.get("model")
            if not model:
                continue
            c = msg.get("content") or []
            if not isinstance(c, list):
                continue
            d = M[model]
            d["asst_turns"] += 1
            nt = 0
            think_c = 0
            say_c = 0
            had_think = False
            for b in c:
                if not isinstance(b, dict):
                    continue
                bt = b.get("type")
                if bt == "tool_use":
                    nt += 1
                    d["tool_uses"] += 1
                    d["toolhist"][b.get("name", "?")] += 1
                elif bt == "thinking":
                    d["think_blocks"] += 1
                    think_c += len(b.get("thinking", ""))
                    had_think = True
                elif bt == "text":
                    say_c += len(b.get("text", ""))
            d["tools_per_turn"].append(nt)
            if nt:
                d["turns_with_tools"] += 1
            if had_think:
                d["turns_with_think"] += 1
                d["think_chars"].append(think_c)
            if say_c:
                d["say_chars"].append(say_c)
    def med(x):
        return round(statistics.median(x), 1) if x else 0
    def mean(x):
        return round(statistics.mean(x), 2) if x else 0
    for model, d in sorted(M.items(), key=lambda kv: -kv[1]["asst_turns"]):
        if d["asst_turns"] < 20:
            continue
        tu = d["tool_uses"]
        print(f"\n===== {model}  (asst_turns={d['asst_turns']}) =====")
        print(f"  tool_uses total          : {tu}")
        print(f"  tools / asst-turn  mean  : {mean(d['tools_per_turn'])}   (parallelism signal)")
        print(f"  multi-tool turns (>=2)   : {sum(1 for x in d['tools_per_turn'] if x>=2)} ({round(100*sum(1 for x in d['tools_per_turn'] if x>=2)/max(1,d['asst_turns']))}%)")
        print(f"  turns_with_think         : {d['turns_with_think']} ({round(100*d['turns_with_think']/max(1,d['asst_turns']))}%)")
        print(f"  think chars  mean/median : {mean(d['think_chars'])} / {med(d['think_chars'])}")
        print(f"  say   chars  mean/median : {mean(d['say_chars'])} / {med(d['say_chars'])}  (verbosity to user)")
        top = d["toolhist"].most_common(16)
        print(f"  tool histogram           : " + ", ".join(f"{k}:{v}" for k, v in top))
        # normalized per-100-tooluses for cross-model comparison
        norm = {k: round(100*v/max(1,tu),1) for k, v in d["toolhist"].items()}
        focus = ["TodoWrite","Workflow","Agent","Task","Read","Grep","Glob","Edit","Write","Bash","PowerShell","AskUserQuestion"]
        print(f"  per-100-tooluses         : " + ", ".join(f"{k}:{norm.get(k,0)}" for k in focus))

def prompts(path):
    for r in iter_records(path):
        if r.get("type") != "user":
            continue
        msg = r.get("message") or {}
        c = msg.get("content")
        if isinstance(c, str) and c.strip():
            print("•", c.strip()[:600], "\n")
        elif isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip():
                    print("•", b["text"].strip()[:600], "\n")

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "metrics"
    if mode == "digest":
        digest(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif mode == "metrics":
        metrics(sys.argv[2:])
    elif mode == "prompts":
        prompts(sys.argv[2])
    else:
        print("unknown mode")
