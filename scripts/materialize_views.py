#!/usr/bin/env python3
"""Materialize the byproduct / byproduct_process view trees as real files.

In the default distribution the two view trees are relative symlinks into sessions/.
This script rebuilds them from the manifests for environments that do not support
symlinks (Windows, some network shares) or for tools that require real files.

  python3 materialize_views.py <dataset-root> --mode hardlink
  python3 materialize_views.py <dataset-root> --mode copy --view byproduct

  hardlink : no extra space on the same filesystem; behaves exactly like real files
             (recommended)
  copy     : fully independent copies; costs about 16.7 GB extra per view
  symlink  : recreate the default distribution form
"""
import argparse, os, shutil, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="the PRISM_2026.07.10-12 directory")
    ap.add_argument("--mode", choices=["hardlink", "copy", "symlink"],
                    default="hardlink")
    ap.add_argument("--view", choices=["byproduct", "byproduct_process", "both"],
                    default="both")
    a = ap.parse_args()

    views = (["byproduct", "byproduct_process"] if a.view == "both" else [a.view])

    for view in views:
        man = os.path.join(a.root, f"{view}.manifest.tsv")
        if not os.path.isfile(man):
            sys.exit(f"manifest not found: {man}")

        n = fallback = 0
        with open(man) as fh:
            next(fh)                                    # header
            for line in fh:
                view_rel, sess_rel = line.rstrip("\n").split("\t")
                dst = os.path.join(a.root, view_rel)
                src = os.path.join(a.root, sess_rel)
                if not os.path.exists(src):
                    sys.exit(f"source session file missing: {src}\n"
                             f"Extract the sessions archives first.")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                if os.path.lexists(dst):
                    os.unlink(dst)
                if a.mode == "hardlink":
                    try:
                        os.link(src, dst)
                    except OSError:                     # across filesystems, fall back
                        shutil.copy2(src, dst)
                        fallback += 1
                elif a.mode == "copy":
                    shutil.copy2(src, dst)
                else:
                    os.symlink(os.path.relpath(src, os.path.dirname(dst)), dst)
                n += 1
                if n % 200000 == 0:
                    print(f"  {view}: {n} ...", flush=True)

        msg = f"{view}: {n} entries created ({a.mode})"
        if fallback:
            msg += f" — {fallback} copied instead (hardlink not possible)"
        print(msg)


if __name__ == "__main__":
    main()
