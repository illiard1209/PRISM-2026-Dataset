# PRISM: Application- and Process-Attributed Network Traffic Dataset

*[한국어 README](README.ko.md)*

Network traffic captured from Windows endpoints and attributed to the **application and
process that generated it**.

One pcap file per session (5-tuple flow); the directory path *is* the label.

| | |
|---|---|
| Collection period | 2026-07-10 – 2026-07-12 (3 days) |
| Monitored hosts | 7 |
| Sessions (pcap files) | 1,320,366 |
| Packets | 199,326,467 |
| Size | 16.7 GB (4.8 GB compressed) |
| Application labels | 89 |
| Process labels | 108 |
| License | Data: CC BY 4.0 / Code: MIT |

> **The data is not stored in this git repository.** At 1.32 M files / 16.7 GB a clone is
> not feasible, so the compressed archives are distributed as **GitHub Release assets**.
> → Download them from [Releases](../../releases/latest).

## Getting the data

```bash
./scripts/download.sh          # download + verify SHA-256 + extract
```

To do it by hand, download the following from the Releases page and verify the checksums:

```bash
sha256sum -c SHA256SUMS
for f in PRISM_sessions_*.tar.zst; do tar -I zstd -xf "$f"; done
tar -I zstd -xf PRISM_views.tar.zst      # only after the session archives
```

| Asset | Size | Contents |
|---|---|---|
| `PRISM_sessions_2026.07.10_part1.tar.zst` | 1.19 GiB | 07-10, hosts 10.0.0.1–4 |
| `PRISM_sessions_2026.07.10_part2.tar.zst` | 1.00 GiB | 07-10, hosts 10.0.0.5–7 |
| `PRISM_sessions_2026.07.11.tar.zst` | 1.21 GiB | 07-11, all hosts |
| `PRISM_sessions_2026.07.12.tar.zst` | 1.28 GiB | 07-12, all hosts |
| `PRISM_views.tar.zst` | 0.08 GiB | View trees + manifests |

Every archive extracts under the same root (`PRISM_2026.07.10-12/`), so they merge into a
single tree. If you only need one day, download only that day's file. 2026-07-10 is split
in two because of the 2 GiB per-file limit on Release assets; each part extracts
independently.

`PRISM_views.tar.zst` consists of relative symlinks into `sessions/`, so the session
archives must be extracted **first**.

## Directory layout

The same 1,320,366 sessions are offered from **three perspectives**. Only `sessions/` holds
real pcap files; the other two are relative symlinks into it and cost no extra disk space.

```
PRISM_2026.07.10-12/
├── sessions/                     # (1) original collection layout — real files
│   └── 2026.07.<DD>/
│       ├── 10.0.0.<N>/           #     anonymized monitored host (N = 1..7)
│       │   └── <application>/    #     application name or <process>.exe
│       │       ├── [<sub-process>.exe/]
│       │       └── [<service|domain>/]
│       │           └── <PROTO>_<ip>_<port>__<ip>_<port>[__<ts>].pcap
│       └── _exp_summary.json     #     per-day, per-host label statistics
├── byproduct/                    # (2) application view (89 labels)
│   └── 2026.07.<DD>/<application>/[...]/*.pcap
├── byproduct_process/            # (3) process view (108 labels)
│   └── 2026.07.<DD>/<process>.exe/[...]/*.pcap
├── byproduct.manifest.tsv        # view path ↔ session path mapping
└── byproduct_process.manifest.tsv
```

| View | Top-level directory = label | Labels | Notes |
|---|---|---|---|
| `sessions/` | (split per host) | — | As collected. Use for per-host analysis |
| `byproduct/` | Application | 89 | Hosts merged; `.exe` stripped from the top-level entry only |
| `byproduct_process/` | Process | 108 | Hosts merged; child processes of multi-process apps lifted to the top level |

The paper's experiments use `byproduct/` (application classification) and
`byproduct_process/` (process classification).

Filenames encode the 5-tuple. When the same 5-tuple recurs, a capture timestamp
(`YYYYMMDD_HHMMSS_mmm`) is appended to disambiguate. Where a view tree would produce a
filename collision, identical files are merged and differing ones keep a `__dupN.pcap`
suffix (122 cases).

> **On filesystems without symlink support** (Windows, some network shares) the two view
> trees may break. Rebuild them as real files from the manifests:
> ```bash
> python3 scripts/materialize_views.py PRISM_2026.07.10-12 --mode hardlink
> ```
> `--mode copy` also works but costs an extra 16.7 GB per view. On the same filesystem,
> `hardlink` behaves exactly like real files at no extra cost.

## Anonymization

**Every IPv4 address belonging to the collecting institution's range was deterministically
replaced** before release, applied consistently to directory names, file names, and packet
IPv4 headers.

| | Replaced with |
|---|---|
| 7 monitored hosts | `10.0.0.1` – `10.0.0.7` |
| 66 other internal hosts | `10.9.<s>.<h>` |

- **Bijective (1:1)** — distinct addresses never collapse into one, so per-host aggregation
  and flow correlation remain possible.
- **/24 subnet structure preserved** — peers that shared a /24 in the original still share
  a `10.9.<s>.0/24`.
- The 7 monitored hosts were deliberately *not* kept in their original subnet; they were
  moved to a separate block so that the data subjects' network position is not disclosed.
- **The reverse mapping table is not published.**

Addresses outside that range (external Internet services, RFC 1918 private addresses) were
left untouched. Payloads, TLS SNI, DNS query names, ports, timestamps, and all
application/process labels are **exactly as captured**.

Verification on the released tree: all 199,326,467 packets were re-read and **zero residual
institutional addresses** were found, in packet headers or in path names.

## Capture characteristics (read before analysis)

- **Link layer**: Ethernet. MAC addresses were already zeroed to `00:00:00:00:00:00` at
  collection time, so no L2 information exists.
- **Protocols**: 100 % IPv4, TCP and UDP only. No IPv6, VLAN, ARP, ICMP, or IP fragmentation.
- **Many TCP/UDP checksums are invalid.** This is a checksum-offload artifact of the
  original capture, not a result of anonymization — the anonymization preserves each
  packet's valid/invalid checksum status exactly (IPv4 header checksums are all valid).
  Analyses relying on checksum validation should account for this.
- **Snaplen truncation**: many packets have `frame.cap_len < frame.len`.
- **Minimum-session filter**: applications with fewer sessions than the threshold
  (default 10) were excluded at collection time. See `excluded_apps` in `_exp_summary.json`.
- **Non-`.exe` buckets excluded**: `System` and `unknown` traffic that cannot be attributed
  to a specific process (139,678 sessions) was excluded from the release, so every published
  session carries a label. Per-host counts remain in `ips[*].excluded_from_release` in
  `_exp_summary.json`.

## Preprocessing

The dataset ships raw per-session pcap files, so you are free to build whatever
preprocessing your model needs. Labels live in the directory path, so no separate label
file is required — use the top-level directory name under `byproduct/` (application) or
`byproduct_process/` (process) directly as the class.

Preprocessing code for the three models used in the paper (2D CNN, ET-BERT, XGBoost) will
be released separately once cleaned up. Each model's input representation and settings are
described in Section 4.1 of the paper.

## Citation

```bibtex
@dataset{prism2026,
  title  = {PRISM: Application- and Process-Attributed Network Traffic Dataset},
  year   = {2026},
  note   = {KNOM Review, Vol.29, No.1},
  url    = {https://github.com/illiard1209/PRISM-2026-Dataset}
}
```

## License

- **Dataset**: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — free to use,
  redistribute, and adapt, including commercially, with attribution.
- **Code** (`scripts/`): MIT — see [`LICENSE-CODE`](LICENSE-CODE).

The data is anonymized but originates from real user activity. Do not attempt to
re-identify individual hosts or users.
