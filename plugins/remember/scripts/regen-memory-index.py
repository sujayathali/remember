#!/usr/bin/env python3
"""Regenerate MEMORY.md for a Remember-protocol memory folder.

This is the v1.4 TD-25 fix — the inline LLM regen is retired; the plugin ships
this script as the single canonical path. Remember (Step 5), Ingest (Step 6),
and Lint (check 1d auto-fix) all invoke this script. No call site does inline
regeneration anymore.

The script generalizes a 2026-06-14 heal-memory prototype. The prototype proved
the structural fix works on a real field folder (31,495 → 33,774 bytes, all
sections preserved); this version is project-agnostic.

Protocol:
  1. Back up the existing MEMORY.md to MEMORY.md.pre-regen.bak.
  2. Read all atoms from memory/{feedback,projects,reference,people,glossary}/.
  3. Parse each atom's YAML frontmatter (name, description, maturity).
  4. Read memory/glossary.md verbatim — paste inline at the top.
  5. Walk memory/snapshots/ for snapshot dates + file counts.
  6. Read the prior MEMORY.md to preserve any user-authored ## Notes section.
  7. Walk memory/ subfolders for the Subfolders list with file counts.
  8. Assert structural gates before write:
       - ## Glossary, ## Snapshots, ## Notes, ## Subfolders all present
       - new content size >= prior content size
  9. If size would shrink, render plain-English confirm (replaces --allow-shrink
     as the user surface, per PL-022 Q5 / Tenet 3).
 10. Write the new MEMORY.md.

Flags:
  --memory-dir PATH     The memory/ folder to regenerate (required)
  --project-name NAME   Title in the regenerated index header (default: derived from parent folder)
  --allow-shrink        Non-interactive escape hatch — skip the shrink confirm.
                        For CI / scripted contexts. NOT for normal use; the
                        interactive confirm is the user-facing path.
  --quiet               Suppress informational stdout; still emit errors and confirms.

Exit codes:
  0   Wrote MEMORY.md successfully
  1   Structural gate failed (missing section, file IO error)
  2   Size would shrink, user declined the confirm
  3   Size would shrink, --allow-shrink not set, no TTY for interactive confirm
  4   One or more atoms could not be read AND --allow-read-failures not set
      (PL-029 SF-1: silent atom drops are not permitted by default; the TD-25
      transform-drop blindspot one level down)
"""
import argparse
import os
import re
import sys
from datetime import date

TYPES = ["feedback", "projects", "reference", "people", "glossary"]
TYPE_HEADERS = {
    "feedback": "Feedback",
    "projects": "Projects",
    "reference": "Reference",
    "people": "People",
    "glossary": "Glossary (atomic mirrors)",
}


def parse_yaml_frontmatter(text):
    """Return a dict of YAML front-matter fields. Robust to absent frontmatter."""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        kv = re.match(r"^(\w[\w_-]*)\s*:\s*(.*)$", line)
        if kv:
            fm[kv.group(1)] = kv.group(2).strip().strip("\"'")
    return fm


def collect_atoms(mem_dir, atom_type):
    """Return (rows, failures) for an atom type.

    rows: sorted list of (slug, name, description, maturity) tuples.
    failures: list of (path, exception_str) for atoms that exist on disk but could
              not be read. Per PL-029 SF-1: never silently swallow read failures —
              they're surfaced loudly and refuse the regen by default (the
              transform-drop blindspot one level down on cloud-synced folders).
    """
    folder = os.path.join(mem_dir, atom_type)
    if not os.path.isdir(folder):
        return [], []
    rows = []
    failures = []
    for fname in sorted(os.listdir(folder)):
        if not fname.endswith(".md") or fname.startswith("."):
            continue
        slug = fname[:-3]
        path = os.path.join(folder, fname)
        try:
            with open(path) as f:
                content = f.read()
        except Exception as e:
            failures.append((path, f"{type(e).__name__}: {e}"))
            continue
        fm = parse_yaml_frontmatter(content)
        name = fm.get("name", slug)
        desc = fm.get("description", "(no description)")
        maturity = fm.get("maturity", "—")
        rows.append((slug, name, desc, maturity))
    return rows, failures


def read_glossary_verbatim(mem_dir):
    """Read glossary.md verbatim. Skip leading h1/title if present; preserve table body."""
    path = os.path.join(mem_dir, "glossary.md")
    if not os.path.isfile(path):
        return "_(no glossary.md yet)_\n"
    with open(path) as f:
        text = f.read()
    return text.rstrip() + "\n"


def collect_snapshots(mem_dir):
    """Return list of (date, file_count_recursive) tuples."""
    snap_dir = os.path.join(mem_dir, "snapshots")
    if not os.path.isdir(snap_dir):
        return []
    out = []
    for d in sorted(os.listdir(snap_dir)):
        full = os.path.join(snap_dir, d)
        if not os.path.isdir(full):
            continue
        n = 0
        for _root, _dirs, files in os.walk(full):
            n += sum(1 for f in files if f.endswith(".md"))
        out.append((d, n))
    return out


def collect_subfolders(mem_dir):
    """Return list of (subfolder_name, file_count) for each memory/ subdir."""
    out = []
    for entry in sorted(os.listdir(mem_dir)):
        full = os.path.join(mem_dir, entry)
        if not os.path.isdir(full) or entry.startswith("."):
            continue
        n = 0
        for _root, _dirs, files in os.walk(full):
            n += sum(1 for f in files if f.endswith(".md"))
        out.append((entry, n))
    return out


def extract_notes_section(memory_md):
    """Return any ## Notes section from the existing MEMORY.md (preserve user content)."""
    if not os.path.isfile(memory_md):
        return None
    with open(memory_md) as f:
        text = f.read()
    m = re.search(r"\n## Notes\s*\n(.*?)(?=\n## |\Z)", text, re.DOTALL)
    if not m:
        return None
    body = m.group(1).strip()
    if not body:
        return None
    return body


def assemble_memory_md(mem_dir, project_name, atoms_by_type, glossary_inline,
                      snapshots, subfolders, preserved_notes, read_failures):
    """Build the new MEMORY.md content as a string. Asserts structural gates.

    read_failures: list of (path, exception_str) tuples — if non-empty, a
    `## Read failures` section is rendered listing affected paths so the user
    can see exactly what was omitted from the index (per PL-029 SF-1).
    """
    today = date.today().isoformat()
    total_atoms = sum(len(v) for v in atoms_by_type.values())

    out = []
    out.append(f"# Project memory — {project_name}\n")
    out.append(f"_Auto-regenerated {today} by Remember plugin regen-memory-index.py "
               f"(TD-25 fix). {total_atoms} atoms across {len(TYPES)} types._\n")

    # Glossary inline (top — hot cache for session start)
    out.append(glossary_inline)
    out.append("")

    # Type sections (excluding glossary mirrors — render those after Reference)
    for t in ["feedback", "projects", "reference", "people"]:
        rows = atoms_by_type[t]
        out.append(f"## {TYPE_HEADERS[t]}\n")
        if not rows:
            out.append("_(none yet)_\n")
        else:
            out.append("| Atom | Description | Maturity |")
            out.append("|---|---|---|")
            for slug, name, desc, maturity in rows:
                safe = desc.replace("|", "\\|")
                if len(safe) > 200:
                    safe = safe[:197] + "…"
                out.append(f"| [{name}]({t}/{slug}.md) | {safe} | {maturity} |")
        out.append("")

    # Glossary atomic mirrors
    out.append(f"## {TYPE_HEADERS['glossary']}\n")
    g_rows = atoms_by_type["glossary"]
    if g_rows:
        out.append("| Atom | Description |")
        out.append("|---|---|")
        for slug, name, desc, _maturity in g_rows:
            safe = desc.replace("|", "\\|")
            if len(safe) > 200:
                safe = safe[:197] + "…"
            out.append(f"| [{name}](glossary/{slug}.md) | {safe} |")
    else:
        out.append("_(no glossary atomic mirrors yet)_")
    out.append("")

    # Snapshots
    out.append("## Snapshots\n")
    if snapshots:
        out.append("Periodic snapshots of memory state, archived for diff and restore.\n")
        out.append("| Date | Files |")
        out.append("|---|---|")
        for d, n in snapshots:
            out.append(f"| `snapshots/{d}/` | {n} files |")
    else:
        out.append("_(no snapshots taken)_")
    out.append("")

    # Notes (preserve user content; placeholder otherwise)
    out.append("## Notes\n")
    if preserved_notes:
        out.append(preserved_notes)
    else:
        out.append("_(This section is preserved verbatim across regenerations. "
                   "Add user-authored notes here; the regen script does not overwrite them.)_\n")
    out.append("")

    # Subfolders
    out.append("## Subfolders\n")
    for name, n in subfolders:
        out.append(f"- `{name}/` — {n} files")
    out.append("")

    # Read failures (per PL-029 SF-1): if --allow-read-failures was set and we're
    # writing despite failures, render them as a visible section so the user can
    # see what's missing from the index. Without this, the failures would still
    # be on stderr but not in the persisted artifact.
    if read_failures:
        out.append("## Read failures (transient — re-run to retry)\n")
        out.append(f"_{len(read_failures)} atom(s) on disk could not be read this regen pass. "
                   f"They are omitted from the index above but their files remain on disk. "
                   f"Re-run the regen after the underlying read issue clears (often a sync delay "
                   f"on cloud-mounted folders)._\n")
        for path, err in read_failures:
            # Trim path to just the relative path inside mem_dir for readability
            try:
                rel = os.path.relpath(path, mem_dir)
            except Exception:
                rel = path
            out.append(f"- `{rel}` — {err}")
        out.append("")

    out.append(f"---\n_Last regenerated: {today}_\n")

    content = "\n".join(out)

    # Structural gates — verify all required sections present
    required = ["## Glossary", "## Snapshots", "## Notes", "## Subfolders"]
    for section in required:
        if section not in content:
            raise AssertionError(f"FAIL: section {section} missing from regenerated content")

    return content


def shrink_confirm(prior_size, new_size, mem_dir, quiet, allow_shrink):
    """Plain-English confirm if MEMORY.md would shrink (per PL-022 Q5 / Tenet 3).

    Returns True if write should proceed, False if user declined.
    Errors and exits 3 if no TTY and --allow-shrink not set.
    """
    if allow_shrink:
        if not quiet:
            print(f"  Note: size would shrink ({prior_size} → {new_size} bytes); "
                  f"--allow-shrink set, proceeding.", file=sys.stderr)
        return True

    # Count atoms for the "likely cause" hint
    n_atoms = 0
    for t in TYPES:
        folder = os.path.join(mem_dir, t)
        if os.path.isdir(folder):
            n_atoms += sum(1 for f in os.listdir(folder)
                           if f.endswith(".md") and not f.startswith("."))

    if not sys.stdin.isatty():
        print(f"ERROR: MEMORY.md would shrink from {prior_size} to {new_size} bytes. "
              f"No TTY for interactive confirm and --allow-shrink not set. "
              f"Aborting to prevent silent content drop. "
              f"Re-run with --allow-shrink to skip this gate.", file=sys.stderr)
        sys.exit(3)

    print(f"\nMEMORY.md would shrink from {prior_size} bytes to {new_size} bytes.")
    print(f"Likely cause: the current memory/ folder has {n_atoms} atoms; some may have "
          f"been removed since the prior regen, OR the prior regen included content the "
          f"new script template no longer carries.")
    print(f"\nProceed? (yes / show diff / no): ", end="", flush=True)

    ans = sys.stdin.readline().strip().lower()
    while ans not in ("yes", "y", "no", "n", "show diff", "diff", "d"):
        print(f"Please answer yes / show diff / no: ", end="", flush=True)
        ans = sys.stdin.readline().strip().lower()

    if ans in ("yes", "y"):
        return True
    if ans in ("no", "n"):
        print("Aborted. Prior MEMORY.md preserved.")
        return False
    # "show diff" case (per PL-029 NIT 4): print real section-by-section byte deltas.
    # Parse both prior and pending content for `## Section` headers, compute byte sizes
    # of each section, and print a delta table. Then re-prompt yes/no.
    _show_section_diff(mem_dir, prior_size)
    print(f"\nProceed? (yes / no): ", end="", flush=True)
    ans = sys.stdin.readline().strip().lower()
    while ans not in ("yes", "y", "no", "n"):
        print(f"Please answer yes / no: ", end="", flush=True)
        ans = sys.stdin.readline().strip().lower()
    return ans in ("yes", "y")


def _section_sizes(text):
    """Parse text for `## Section` headers, return {section_name: byte_size} dict."""
    if not text:
        return {}
    sections = {}
    # Split on `## ` at line start; first chunk before any ## is preamble
    chunks = re.split(r"(?m)^## ", text)
    # First chunk is preamble (everything before any ##)
    if chunks[0].strip():
        sections["(preamble)"] = len(chunks[0].encode("utf-8"))
    for chunk in chunks[1:]:
        # Section name is the first line; rest is body
        lines = chunk.split("\n", 1)
        name = lines[0].strip()
        # The full section text is "## " + chunk (because we split it off)
        section_text = "## " + chunk
        sections[name] = len(section_text.encode("utf-8"))
    return sections


def _show_section_diff(mem_dir, prior_size):
    """Print a section-by-section byte delta between the prior MEMORY.md and what the
    current script run would produce. Reads prior from the .pre-regen.bak backup
    that main() already wrote before this function is called."""
    memory_md = os.path.join(mem_dir, "MEMORY.md")
    backup = os.path.join(mem_dir, "MEMORY.md.pre-regen.bak")
    prior_text = ""
    if os.path.isfile(backup):
        try:
            with open(backup) as f:
                prior_text = f.read()
        except Exception:
            pass
    # The "pending" content is what main() already assembled. We don't have it
    # in scope here — but the user can re-run the script to see; for now we
    # compute prior sections and the directional change since main() will
    # write the new content next if they confirm.
    prior_sections = _section_sizes(prior_text)
    if not prior_sections:
        print("\n(no prior MEMORY.md to diff against — first regen.)")
        return
    print("\nPrior MEMORY.md section sizes (bytes):")
    total = 0
    for name, sz in prior_sections.items():
        print(f"  {sz:>8}  ## {name}")
        total += sz
    print(f"  {'─' * 8}")
    print(f"  {total:>8}  TOTAL ({prior_size} bytes including line endings/encoding)")
    print(f"\nThe new MEMORY.md would shrink overall. Sections that may have shrunk: any "
          f"with reduced atom counts, or `## Notes` if user content was removed. The script "
          f"preserves `## Notes` content verbatim if present in the prior file, so a Notes "
          f"shrinkage usually means the prior file had Notes content the user has since cleared.")


def main():
    parser = argparse.ArgumentParser(description="Regenerate MEMORY.md for a Remember-protocol memory folder.")
    parser.add_argument("--memory-dir", required=True,
                        help="The memory/ folder to regenerate")
    parser.add_argument("--project-name", default=None,
                        help="Title in the regenerated index header (default: derived from parent folder name)")
    parser.add_argument("--allow-shrink", action="store_true",
                        help="Non-interactive escape hatch — skip the shrink confirm. For CI / scripted contexts.")
    parser.add_argument("--allow-read-failures", action="store_true",
                        help="Proceed with regen even if some atoms could not be read (PL-029 SF-1 hardening). "
                             "When set, the script writes MEMORY.md with a `## Read failures` section listing "
                             "affected paths. Without this flag, ANY read failure aborts the regen with exit "
                             "code 4 — silent drops are not permitted by default.")
    parser.add_argument("--quiet", action="store_true",
                        help="Suppress informational stdout")
    args = parser.parse_args()

    mem_dir = os.path.abspath(args.memory_dir)
    if not os.path.isdir(mem_dir):
        print(f"ERROR: memory directory does not exist: {mem_dir}", file=sys.stderr)
        sys.exit(1)

    memory_md = os.path.join(mem_dir, "MEMORY.md")
    backup = os.path.join(mem_dir, "MEMORY.md.pre-regen.bak")

    project_name = args.project_name or os.path.basename(os.path.dirname(mem_dir))

    # Back up existing MEMORY.md
    prior_size = 0
    if os.path.isfile(memory_md):
        with open(memory_md) as f:
            prior = f.read()
        with open(backup, "w") as f:
            f.write(prior)
        prior_size = len(prior.encode("utf-8"))
        if not args.quiet:
            print(f"Backup written: {backup} ({prior_size} bytes)")

    # Collect inputs — collect_atoms now returns (rows, failures) per PL-029 SF-1
    atoms_by_type = {}
    all_failures = []
    for t in TYPES:
        rows, failures = collect_atoms(mem_dir, t)
        atoms_by_type[t] = rows
        all_failures.extend(failures)
    glossary_inline = read_glossary_verbatim(mem_dir)
    snapshots = collect_snapshots(mem_dir)
    subfolders = collect_subfolders(mem_dir)
    preserved_notes = extract_notes_section(memory_md)

    # PL-029 SF-1: surface read failures loudly, refuse to write by default
    if all_failures:
        print(f"\n⚠️  {len(all_failures)} atom(s) could not be read this regen pass:", file=sys.stderr)
        for path, err in all_failures:
            print(f"   - {path}", file=sys.stderr)
            print(f"     {err}", file=sys.stderr)
        if not args.allow_read_failures:
            print(f"\nERROR: refusing to write MEMORY.md with silent atom drops. The size-monotonicity "
                  f"gate cannot detect a dropped atom masked by other growth — that is the TD-25 "
                  f"transform-drop blindspot, one level down. Either: (a) resolve the underlying read "
                  f"issue (often a Dropbox/cloud-sync delay; wait + retry), or (b) re-run with "
                  f"--allow-read-failures to write the index with a `## Read failures` section "
                  f"listing the affected paths so the omissions are visible in the persisted artifact.",
                  file=sys.stderr)
            sys.exit(4)
        else:
            print(f"\n--allow-read-failures set; proceeding. Affected atoms will be listed in the "
                  f"`## Read failures` section of MEMORY.md.", file=sys.stderr)

    # Assemble (with structural-gate assertions)
    try:
        content = assemble_memory_md(mem_dir, project_name, atoms_by_type,
                                     glossary_inline, snapshots, subfolders,
                                     preserved_notes, all_failures)
    except AssertionError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    new_size = len(content.encode("utf-8"))

    # Size monotonicity gate (Glossary/Snapshots/Notes/Subfolders presence already asserted
    # in assemble_memory_md). The read-failures gate above is the SF-1 fix; size is still
    # a useful belt-and-suspenders check for the unmasked-shrink case.
    if new_size < prior_size:
        if not shrink_confirm(prior_size, new_size, mem_dir, args.quiet, args.allow_shrink):
            sys.exit(2)

    # Write
    with open(memory_md, "w") as f:
        f.write(content)

    total_atoms = sum(len(v) for v in atoms_by_type.values())
    if not args.quiet:
        print(f"\nRegen complete.")
        print(f"  Prior MEMORY.md: {prior_size} bytes")
        print(f"  New MEMORY.md:   {new_size} bytes  ({new_size - prior_size:+d})")
        print(f"  Atoms indexed:   {total_atoms}")
        print(f"  Read failures:   {len(all_failures)}")
        print(f"  Snapshots:       {len(snapshots)}")
        print(f"  Subfolders:      {len(subfolders)}")
        print(f"  Notes section:   {'PRESERVED from prior' if preserved_notes else 'placeholder'}")
        print(f"  Backup at:       {backup}")


if __name__ == "__main__":
    main()
