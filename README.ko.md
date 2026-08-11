# PRISM: Application- and Process-Attributed Network Traffic Dataset

*[English README](README.md)*

Windows 엔드포인트에서 수집한 네트워크 트래픽을 **애플리케이션·프로세스 단위로 귀속**시킨
데이터셋과, 이를 재현하기 위한 익명화·전처리 코드.

세션(5-tuple flow) 하나당 pcap 파일 하나이며, 디렉토리 경로가 곧 라벨이다.

| | |
|---|---|
| 수집 기간 | 2026.07.10 – 2026.07.12 (3일) |
| 관측 호스트 | 7 |
| 세션(pcap) | 1,320,366 |
| 패킷 | 199,326,467 |
| 크기 | 16.7 GB (압축 4.8 GB) |
| 애플리케이션 라벨 | 89종 |
| 라이선스 | 데이터 CC BY 4.0 / 코드 MIT |

> **데이터는 git 저장소에 포함되어 있지 않다.** 130만 개 파일 / 16.7 GB 규모라
> clone 이 불가능하므로, 압축 아카이브를 **GitHub Release 자산**으로 배포한다.
> → [Releases](../../releases/latest) 에서 내려받을 것.

## 데이터 받기

```bash
./scripts/download.sh          # 내려받기 + SHA256 검증 + 압축 해제
```

수동으로 받으려면 Releases 페이지에서 다음을 내려받아 무결성을 확인한다.

```bash
sha256sum -c SHA256SUMS
for f in PRISM_sessions_*.tar.zst; do tar -I zstd -xf "$f"; done
tar -I zstd -xf PRISM_views.tar.zst      # 반드시 sessions 를 푼 뒤에
```

| 자산 | 크기 | 내용 |
|---|---|---|
| `PRISM_sessions_2026.07.10_part1.tar.zst` | 1.19 GiB | 07.10 / 호스트 10.0.0.1–4 |
| `PRISM_sessions_2026.07.10_part2.tar.zst` | 1.00 GiB | 07.10 / 호스트 10.0.0.5–7 |
| `PRISM_sessions_2026.07.11.tar.zst` | 1.21 GiB | 07.11 전체 |
| `PRISM_sessions_2026.07.12.tar.zst` | 1.28 GiB | 07.12 전체 |
| `PRISM_views.tar.zst` | 0.08 GiB | 관점 트리 + manifest |

모든 아카이브가 같은 루트(`PRISM_2026.07.10-12/`)로 풀리므로 하나의 트리로 병합된다.
하루치만 필요하면 해당 일자 파일만 받으면 된다. 2026.07.10 은 GitHub Release 의
파일당 2 GiB 제한 때문에 호스트 그룹 기준으로 두 개로 나뉘어 있으며, 각 파트는
독립적으로 해제된다.

`PRISM_views.tar.zst` 는 `sessions/` 를 가리키는 상대 심볼릭 링크로 이루어져 있으므로
반드시 sessions 아카이브를 먼저 풀어야 한다.

## 디렉토리 구조

같은 1,320,366개 세션을 **세 가지 관점**으로 제공한다. 실제 pcap 파일은 `sessions/`에만
있고, 나머지 두 관점은 그리로 향하는 상대 심볼릭 링크라 디스크를 추가로 쓰지 않는다.

```
PRISM_2026.07.10-12/
├── sessions/                     # ① 수집 원본 레이아웃 (실제 파일)
│   └── 2026.07.<DD>/
│       ├── 10.0.0.<N>/           #   익명화된 관측 호스트 (N = 1..7)
│       │   └── <application>/    #   애플리케이션명 또는 <process>.exe
│       │       ├── [<sub-process>.exe/]
│       │       └── [<service|domain>/]
│       │           └── <PROTO>_<ip>_<port>__<ip>_<port>[__<ts>].pcap
│       └── _exp_summary.json     #   일자·호스트별 앱 세션 통계
├── byproduct/                    # ② 응용 단위 관점 (89 라벨)
│   └── 2026.07.<DD>/<application>/[...]/*.pcap
├── byproduct_process/            # ③ 프로세스 단위 관점 (108 라벨)
│   └── 2026.07.<DD>/<process>.exe/[...]/*.pcap
├── byproduct.manifest.tsv        # 관점 ↔ sessions 경로 대응표
└── byproduct_process.manifest.tsv
```

| 관점 | 최상위 디렉토리 = 라벨 | 라벨 수 | 특징 |
|---|---|---|---|
| `sessions/` | (호스트별로 나뉨) | — | 수집 원본 그대로. 호스트 단위 분석용 |
| `byproduct/` | 애플리케이션 | 89 | 호스트 통합. 최상위 항목의 `.exe`만 제거 |
| `byproduct_process/` | 프로세스 | 108 | 호스트 통합. 멀티프로세스 앱은 자식 프로세스를 최상위로 펼침 |

논문 실험은 `byproduct/`(응용 분류)와 `byproduct_process/`(프로세스 분류)를 사용했다.

> **심볼릭 링크를 지원하지 않는 환경**(Windows 등)에서는 두 관점 트리가 깨질 수 있다.
> 그럴 때는 manifest로 실파일을 만들면 된다.
> ```bash
> python3 scripts/materialize_views.py PRISM_2026.07.10-12 --mode hardlink
> ```
> `--mode copy`도 지원하지만 관점당 16.7 GB를 추가로 쓴다. 같은 파일시스템이라면
> `hardlink`가 추가 용량 없이 실파일과 동일하게 동작한다.

## 익명화

수집 기관 대역 `163.152.0.0/16`에 속하는 **모든 IPv4 주소**를 결정적으로 치환했다.
디렉토리명·파일명·패킷 IPv4 헤더 세 곳에 일관 적용된다.

| 구분 | 치환 후 |
|---|---|
| 관측 대상 호스트 7대 | `10.0.0.1` ~ `10.0.0.7` |
| 그 외 기관 내부 호스트 66개 | `10.9.<s>.<h>` |

- **1:1 전단사** — 서로 다른 주소가 합쳐지지 않으므로 호스트 단위 집계·흐름 상관이 유지된다.
- **/24 서브넷 구조 보존** — 원본에서 같은 /24였던 피어는 익명화 후에도 같은 `10.9.<s>.0/24`에 있다.
- 관측 대상 7대는 원래 서브넷 소속을 의도적으로 보존하지 않고 별도 블록에 배치했다.
- **역매핑 테이블은 공개하지 않는다.**

`163.152.0.0/16` 이외 주소(외부 인터넷 서비스, RFC1918 사설 주소)는 변경하지 않았다.
페이로드, TLS SNI, DNS 질의명, 포트, 타임스탬프, 애플리케이션 라벨은 **전부 원본 그대로**다.

공개본 전수 검증 결과, 패킷 199,326,467개를 다시 읽어 **기관 대역 주소 잔존 0건**을
확인하였다(패킷 헤더·경로명 모두).

## 캡처 특성 (분석 전 반드시 확인)

- **링크 계층**: Ethernet. MAC 주소는 수집 단계에서 `00:00:00:00:00:00`으로 영점화되어
  있어 L2 정보가 존재하지 않는다.
- **프로토콜**: 100% IPv4, TCP·UDP만. IPv6·VLAN·ARP·ICMP·IP 단편화는 없다.
- **TCP/UDP 체크섬 불량이 다수 존재한다.** 원본 캡처 단계의 checksum offload 아티팩트이며
  익명화로 생긴 것이 아니다. 익명화는 각 패킷의 체크섬 유효/불량 상태를 원본과 동일하게
  보존한다(IPv4 헤더 체크섬은 전량 유효). 체크섬 검증에 의존하는 분석은 오탐에 주의.
- **snaplen 절단**: 다수 패킷이 `frame.cap_len < frame.len`이다.
- **세션 필터**: 세션 수가 임계값(기본 10) 미만인 애플리케이션은 수집 시 제외되었다.
  제외 내역은 `_exp_summary.json`의 `excluded_apps` 참조.
- **비-`.exe` 버킷 제외**: 특정 프로세스에 귀속시킬 수 없는 `System`·`unknown`
  (139,678 세션)은 공개본에서 제외했다. 따라서 모든 세션이 라벨을 가진다.
  제외 수치는 `_exp_summary.json`의 `ips[*].excluded_from_release`에 남아 있다.

## 전처리

본 데이터셋은 세션별 원본 pcap 파일을 그대로 제공하므로, 분류 모델에 맞는 전처리는
이용자가 자유롭게 구성할 수 있다. 라벨은 디렉토리 경로에 그대로 담겨 있어 별도의
라벨 파일 없이 `byproduct/`(응용 단위) 또는 `byproduct_process/`(프로세스 단위)의
최상위 디렉토리명을 그대로 클래스로 사용하면 된다.

논문 실험에 사용한 세 모델(2D CNN, ET-BERT, XGBoost)의 전처리 코드는 정리 후 별도로
공개할 예정이다. 각 모델의 입력 표현과 하이퍼파라미터는 논문 4.1절에 기술되어 있다.

## 인용

```bibtex
@dataset{prism2026,
  title  = {PRISM: Application- and Process-Attributed Network Traffic Dataset},
  year   = {2026},
  note   = {KNOM Review, Vol.29, No.1},
  url    = {https://github.com/illiard1209/PRISM-2026-Dataset}
}
```

## 라이선스

- **데이터셋**: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — 출처를 표시하면
  상업적 이용을 포함해 자유롭게 사용·재배포·변형할 수 있다.
- **코드** (`scripts/`): MIT — [`LICENSE-CODE`](LICENSE-CODE)

데이터는 익명화되었으나 실제 사용자 활동에서 유래한 트래픽이다. 개별 호스트나 이용자를
재식별하려는 시도는 하지 말 것.
