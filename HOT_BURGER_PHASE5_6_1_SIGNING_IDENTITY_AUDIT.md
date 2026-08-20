# HOT BURGER — PHASE 5.6.1
## APK Signing Identity Audit (Release Candidate b9b4120 / CI run 32314746960)

**Date:** 2026-08-20 | **Scope:** READ-ONLY evidence audit of the EXISTING release artifact — no rebuild, no re-sign, no modifications
**Author:** Manus AI

---

## 1. Executive Decision

| Field | Value |
|---|---|
| **DECISION** | **SIGNING NOT VERIFIED — RELEASE HANDOFF BLOCKED** |
| Classification | **SIGNING NOT VERIFIED — DEBUG CERTIFICATE** |
| Artifact | Release APK, CI run 32314746960, commit b9b4120 |
| Certificate | `C=US, O=Android, CN=Android Debug` (all three ABIs) |
| SHA-256 fingerprint | `72ef2fb0de290d3a69b561039a9c82ce9b80e8d5f152a07bba37467b9d6d74f7` |
| Provenance | SOURCE/ARTIFACT MATCH = VERIFIED (unchanged from Phase 5.6.0) |
| P0 / P1 / P2 | 0 / 1 / 1 |
| Files modified | 0 |

The artifact identity, CI provenance, APK structural integrity, and cryptographic signature validity are all **fully verified**. However, the certificate that signed the Release Candidate is cryptographically identifiable as the **Android SDK auto-generated debug certificate** (`CN=Android Debug`, Serial 1, self-signed, 30-year validity — the exact profile of an auto-generated debug keystore). The repository contains **no production signing configuration and no documented production certificate fingerprint**. Per the governing rule of this phase, the final decision is **SIGNING NOT VERIFIED — RELEASE HANDOFF BLOCKED**. This is a deliberate, owner-known configuration (documented since Phase 5.6.0); no data or financial integrity is affected — only the deployment trust posture of the shipping APK is unresolved.

## 2. Locked Baseline Identity

| Check | Result |
|---|---|
| HEAD SHA | `b9b4120714702c79ea47a03bef6af1ecea0958d7` |
| Branch | `main` |
| origin/main | `b9b4120714702c79ea47a03bef6af1ecea0958d7` — **identical** |
| Tracked changes | **0** (clean worktree, clean index) |
| Last commit | `b9b4120 (HEAD → main, origin/main, origin/HEAD) Fix CI BI regression environment gate` |
| Parent | `dd8bc50` |
| pubspec version | `3.9.0+18` |
| Fingerprint spot-check vs freeze record | `financial_calculator.dart = 89dce2187006159244e68f0f49b3c93d` ✔, `app_provider.dart = 7972d9251a7c6f84259fc89118e98d81` ✔, `database_helper.dart = 8ae68d3f5c30d04ad80e9b98d651eea5` ✔ |

> **CLAIM:** The signing audit was performed against the exact frozen baseline. **EVIDENCE:** `git rev-parse HEAD = origin/main` both resolve to `b9b4120…`; `git status --porcelain` shows zero tracked modifications; md5 fingerprints of the three critical files match the Phase 5.5.0 freeze record. **RESULT:** Baseline identity = LOCKED. **IMPACT:** Audit conclusions apply to the approved Release Candidate, not to any other state.

## 3. Exact Artifact Identity

The existing artifact was located live on GitHub (READ-ONLY, no regeneration) and matches the previously approved record byte-for-byte:

| Property | Value |
|---|---|
| Originating run | CI run `32314746960` (GitHub Actions, workflow `build_apk.yml`) |
| Run conclusion | `success` — job `build` success, `headSha = b9b4120714702c79ea47a03bef6af1ecea0958d7` (**exact match**, via GitHub API) |
| Artifact 1 | `release-apk` — 27,476,227 bytes — created `2026-08-19T23:52:47Z` |
| Artifact 2 | `release-apk-raw` — 27,490,459 bytes — created `2026-08-19T23:52:49Z` |
| ZIP contents | `app-arm64-v8a-release.apk` 9,342,970 B · `app-armeabi-v7a-release.apk` 9,097,239 B · `app-x86_64-release.apk` 9,486,069 B (all timestamps `2026-08-19 23:52:43 +0000`) |

The downloaded artifact ZIP was hashed (`sha256sum` of `hot-burger-release.zip`: `88c93d9e69a3db27aa4f49c97c223bb29074b56e265f6f345351a914ccb680d4`), extracted to a fresh inspection directory (the original artifact remains untouched), and its contents hashed. Sizes match the Phase 5.6.0 record exactly (27,476,227 / 27,490,459).

> **CLAIM:** This is the exact artifact produced by the approved CI run, not a regenerated build. **EVIDENCE:** Sizes match byte-for-byte; timestamps sit inside the CI artifact window; run API shows `headSha = b9b4120` and no subsequent runs produced new release artifacts on main. **RESULT:** ARTIFACT IDENTITY = VERIFIED. **IMPACT:** The signing evidence in this report belongs to the approved artifact only.

## 4. Artifact SHA-256

| APK | SHA-256 | Size |
|---|---|---|
| `app-arm64-v8a-release.apk` | `e59b6258727ea62c9c42f59a4da74da11622e6f097e7b1a4577d0d1d2cdb310a` | 9,342,970 B |
| `app-armeabi-v7a-release.apk` | `16f9a8066879fa532bdea29dd6e824a5718687aeda75b46aec97d267e90d3b8e` | 9,097,239 B |
| `app-x86_64-release.apk` | `cab2555d2ae2e09e8ac97203b23030a51af3b7ab52f69147713eaf43e2859fb2` | 9,486,069 B |

Hashes are stable across extraction and independent re-runs (`sha256sum`, deterministic). These values are recorded for any future identity cross-checks and are identical to what the CI builder produced in run 32314746960.

## 5. APK Package Identity

`aapt2 dump badging` (READ-ONLY) on the inspected arm64 artifact reports:

> `package: name='com.hotburger.hot_burger' versionCode='2018' versionName='3.9.0' platformBuildVersionName='14' platformBuildVersionCode='34' compileSdkVersion='34'`

The `applicationId` is exactly `com.hotburger.hot_burger` as required, and the package name is consistent across all three ABIs (same certificate, same lineage — one builder, one run).

## 6. Version / Build Identity

| Expectation | APK manifest | Status |
|---|---|---|
| applicationId `com.hotburger.hot_burger` | `com.hotburger.hot_burger` | MATCH |
| versionName `3.9.0` | `3.9.0` | MATCH |
| pubspec build `18` | `versionCode = 2018` | **OBSERVED DISCREPANCY — documented below** |

The manifest reports `versionCode='2018'` whereas the pubspec declares `3.9.0+18` (build 18). The Gradle config wires `versionCode = flutter.versionCode` and the CI pipeline passes the build number through the Flutter version mapping; the observed value `2018` differs from the canonical mapping convention (`390018`-style) and does not correspond to build 18. **This is a metadata-hygiene observation, not a signature or integrity defect** — the APK belongs to the correct commit and run. It is recorded here as an evidence gap (Section 19, G-02) so that a future release phase can confirm how the CI builder sets `flutter.versionCode`.

## 7. APK Signature Verification

`apksigner verify --verbose --print-certs` (Android SDK build-tools, READ-ONLY) on **all three ABIs**:

| Check | Result |
|---|---|
| Overall verification | **Verifies** (signature is cryptographically valid) |
| v1 scheme (JAR signing) | true |
| v2 scheme (APK Signature Scheme v2) | true |
| v3 / v3.1 / v4 | false |
| SourceStamp | false |
| Number of signers | 1 |
| Key algorithm / size | RSA 2048 |

All warnings produced are the standard `META-INF/… not protected by signature` notices on library metadata entries — an expected property of v1 scheme coverage, since v2 fully covers the archive; **not an integrity defect**.

> **CLAIM:** The APK signature is cryptographically valid and the APK contents are consistent with the signature. **EVIDENCE:** `apksigner verify` returns "Verifies" on all three ABIs with v1+v2 schemes present. **RESULT:** APK INTEGRITY = VALID. **IMPACT:** The artifact is structurally sound and was genuinely produced and signed by the recorded builder; it was not corrupted or tampered in transit.

## 8. Certificate Details

| Property | Value |
|---|---|
| Subject (DN) | `C=US, O=Android, CN=Android Debug` |
| Issuer (DN) | `C=US, O=Android, CN=Android Debug` (self-signed) |
| Serial number | 1 |
| Valid from | Wed Aug 19 23:52:23 UTC 2026 |
| Valid until | Fri Aug 11 23:52:23 UTC 2056 (30-year validity) |
| Signature algorithm | SHA256withRSA |
| Certificate version | 1 |
| Key | RSA 2048 |

The identity profile — `CN=Android Debug`, self-signed, serial 1, exactly 30 years of validity, created at the artifact build timestamp (`23:52:23`, twenty seconds before the APK timestamps `23:52:43`) — is the unmistakable profile of an **auto-generated debug keystore** produced by the Android SDK's default keystore tooling at build time.

## 9. Certificate Fingerprints

Identical on all three ABIs (single signer, single lineage):

| Digest | Fingerprint |
|---|---|
| SHA-256 | `72ef2fb0de290d3a69b561039a9c82ce9b80e8d5f152a07bba37467b9d6d74f7` |
| SHA-1 | `76ccbba569e88194107dbb9c384c636401cfe027` |
| MD5 | `0698d9eaa654a3e4ba5344f7096545d7` |
| Public key SHA-256 | `399c6c1e7febcef829dcf837b075a4fd109b231ab5dc534ad942580e5f2556f3` |

## 10. Debug-vs-Production Determination

| Indicator | Observation | Interpretation |
|---|---|---|
| Certificate CN | `Android Debug` | Standard debug-keystore subject |
| Validity period | Exactly 30 years | Auto-generated default (Gradle/SDK keystore tool) |
| Serial | 1 | Fresh auto-generated keystore |
| Creation time | 23:52:23 UTC on the build day, seconds before the APK | Generated at build time, per-machine default keystore |
| Issuer = Subject | Self-signed | Consistent with both debug and production, but combined with CN = debug |
| Subject DN | `C=US, O=Android, CN=Android Debug` | The canonical Android **debug** certificate identity |

> **CLAIM:** The Release Candidate APK is signed with the Android debug certificate, not a production certificate. **EVIDENCE:** Verbatim certificate output from `apksigner --print-certs` and `keytool -printcert -jarfile` on the inspected artifact, all three ABIs. **RESULT:** **SIGNING NOT VERIFIED — DEBUG CERTIFICATE**. **IMPACT:** The artifact cannot be deployed to a Google Play production track (Play refuses debug-signed APKs outright) nor safely treated as a production-signed build; Play Store upgrades require a consistent production identity.

The determination is made on cryptographic grounds only. Per the governing rule, it is NOT inferred from the APK filename (`*-release.apk`), the release build type, `minifyEnabled true`, `shrinkResources true`, CI success, or artifact provenance — all of which are release-*configuration* properties, none of which says anything about *which key* signed the archive.

## 11. Production Certificate Evidence

A READ-ONLY search of the entire repository for an authoritative production signing identity found:

| Search target | Result |
|---|---|
| Documented production SHA-256 / SHA-1 fingerprint in any file | **Not found** |
| Release certificate fingerprint documentation | **Not found** |
| Production keystore metadata / Play App Signing identity | **Not found** |
| CI signing secrets documentation or secret references (values never exposed) | **Not found** — workflow contains zero signing/keystore/STORE references |
| Keystore binaries (`.jks` / `.keystore` / `.p12`) in the tree | **Not found** (`find` over the whole repo, excluding `.git`, returns zero hits) |
| `key.properties` checked in | **Not present** — `android/.gitignore` explicitly excludes it (correct practice) |
| `android/gradle.properties` signing entries | **None** — only JVM args and AndroidX toggles |

The only signing configuration that exists in the repository is the explicit debug assignment documented in Section 13. Therefore the production certificate fingerprint **cannot be established from repository or CI evidence** — and the certificate observed in the artifact is positively identified as debug, so no fallback to "unknown certificate" ambiguity is needed.

> **SECURITY RULE COMPLIANCE:** No private keys, keystore binaries, passwords, or secret values were encountered or disclosed anywhere in this audit. All evidence consists solely of public certificate metadata and build configuration text.

## 12. CI Signing Path

The signing path actually taken by run 32314746960, established from the CI record and the configuration files (not from assumption about future builds):

> **CI (GitHub Actions, `build_apk.yml`) → `flutter build apk --release` → Gradle `assembleRelease` → `buildTypes.release { signingConfig = signingConfigs.debug }` → Android SDK auto-generated debug keystore → final APK → artifact `release-apk`**

Three independent pieces of evidence converge: (1) the workflow file contains zero signing configuration or secret references, so Gradle's in-repo config is the sole authority; (2) `android/app/build.gradle` lines 35–37 explicitly assign `signingConfig = signingConfigs.debug` inside the release block, accompanied by the stock template comment:

```
// TODO: Add your own signing config for the release build.
// Signing with the debug keys for now, so `flutter run --release` works.
signingConfig = signingConfigs.debug
```

(3) the artifact's certificate itself (`CN=Android Debug`, serial 1, generated at `23:52:23` UTC) is the direct output of that path. The question "what certificate signed THIS artifact?" is therefore answered by the artifact's own certificate: **the debug certificate**.

## 13. Signing Configuration Analysis

| Question | Answer | Evidence |
|---|---|---|
| 1. Which signingConfig did the approved CI build use? | `signingConfigs.debug` | `android/app/build.gradle:35-37`; artifact certificate |
| 2. Was release explicitly assigned `signingConfigs.debug`? | **Yes — deliberately** | Same lines; explicit, commented (stock Flutter template) |
| 3. Is a production signing configuration defined? | **No** | No `signingConfigs.release` block, no `key.properties` usage, no secret wiring in workflow |
| 4. Is the production configuration actually used? | N/A — does not exist | — |
| 5. Is signing controlled by environment/secret variables? | **No** | Workflow has zero signing refs; no `env`/`secrets` for signing |
| 6. Can the CI build silently fall back to debug signing? | Not silent — debug is the **only** configured path | Explicit assignment; absence of any alternative |
| 7. Does the repository contain a dangerous release fallback? | **Yes, by design** | Release builds ship with debug keys — the exact blocker of this phase |

The "dangerous release fallback" is fully transparent (an explicit TODO comment), so there is no deception risk — but it is nonetheless a release governance blocker per the severity policy (P1: release APK signed with debug certificate).

## 14. Source → CI → APK Provenance Chain

| Link | Evidence | Status |
|---|---|---|
| Source commit | `b9b4120` on `main` (clean, freeze-matched) | VERIFIED |
| Commit → CI run | `headSha = b9b4120…` (GitHub API, run 32314746960) | VERIFIED |
| CI run → build | `flutter build apk --release` executed in run 32314746960 (CI log) | VERIFIED |
| Build → signing key | `signingConfig = signingConfigs.debug` (gradle:35-37) + artifact certificate (`CN=Android Debug`) | VERIFIED |
| Build → artifact | Sizes 27,476,227 / 27,490,459 exact; timestamps inside CI window | VERIFIED |
| Artifact → SHA-256 | Stable, recorded in §4 | VERIFIED |

The complete chain is unbroken and traceable from source to artifact. The only failing element of the chain is the **trust posture of the terminal node**: the APK is signed, but with the debug certificate.

## 15. APK Integrity

| Check | Result |
|---|---|
| Signature verification | Succeeds (apksigner "Verifies") |
| Structural validity | Valid (badging dump, APK parse, verification all succeed) |
| Certificate readability | Full certificate metadata readable via `keytool` / `apksigner` |
| Package identity | `com.hotburger.hot_burger` — correct |
| Corruption / transit tampering | None detected (stable hashes, valid v2 block) |
| No unzip-and-repack | Complied — original artifact untouched; extraction was a read-only inspection copy |

## 16. Play/App-Store Signing Evidence

No evidence exists in the repository or CI record for any Google Play deployment path: no Play App Signing upload key documentation, no store listing configuration, no keystore upload procedure. The governing rule is applied without softening:

> **PLAY APP SIGNING IDENTITY NOT VERIFIED**

This is stated as an evidence absence, not as a defect: the audit does not claim the APK is unacceptable to Google Play for any reason beyond the independently established fact that it is debug-signed (which alone would cause Play rejection of a production upload). No Play acceptance claim is made anywhere in this report.

## 17. Security Findings

No private keys, keystore binaries, passwords, GitHub secrets, or encoded credentials were encountered anywhere in this audit; the workflow contains no signing secrets, and `key.properties` is correctly gitignored. The only finding is configuration-level: the release build type deliberately uses the debug keystore.

| ID | Severity | Finding | Basis | Status |
|---|---|---|---|---|
| **SI-F-01** | **P1** | Release APK signed with the Android auto-generated debug certificate (`CN=Android Debug`, SHA-256 `72ef2fb0…74f7`) on all three ABIs | `apksigner`/`keytool` on the inspected artifact | **OPEN — release blocker** |
| **SI-F-02** | **P2** | No production signing identity (fingerprint, keystore, CI secret wiring) exists or is documented anywhere in the repository or CI | Full-tree READ-ONLY search, §11 | OPEN — prerequisite for closing SI-F-01 |
| G-02 | Observation | `versionCode` in APK manifest (`2018`) does not match the canonical mapping of pubspec build 18 | `aapt2 dump badging` (§6) | Documented, non-blocking |

## 18. Adversarial Verification

Each falsification question was posed and answered from evidence:

| # | Question | Evidence-based answer |
|---|---|---|
| 1 | Could this APK secretly be debug-signed? | **Yes — it demonstrably is.** The certificate subject is literally `Android Debug`. |
| 2 | Could CI have silently fallen back to `signingConfigs.debug`? | Not silently — debug is the **only** configured path (explicit assignment, no production alternative exists). The fallback is overt, which makes it a governance blocker rather than a compromise. |
| 3 | Could the artifact come from another commit? | No — `headSha` matches `b9b4120` exactly (GitHub API); worktree frozen. |
| 4 | Could the artifact have been rebuilt after the approved CI run? | No — artifact sizes match byte-for-byte; timestamps sit inside the CI window; no later run produced release artifacts on main. |
| 5 | Could the production certificate fingerprint differ? | N/A — no production certificate exists to differ from. SI-F-02. |
| 6 | Could applicationId differ from the expected package? | No — manifest `package` is `com.hotburger.hot_burger`, matching expectation exactly. |
| 7 | Could version/build metadata differ? | Partially — `versionCode` observed as `2018` vs expected mapping of build 18 (G-02, hygiene only). |
| 8 | Could the certificate be expired? | No — valid until 2056-08-11. |
| 9 | Could signing verification succeed while production identity remains unknown? | **Yes — this is exactly the situation audited.** "Verifies" proves authenticity of *a* signer, not *the required* signer. Provenance correctness (§3-4) does not imply signing correctness. |
| 10 | Could the release be accepted technically but still be unsuitable for production deployment? | **Yes.** The APK installs and runs (debug-signed), but debug certificates cannot be uploaded to a production Play track and give no upgrade continuity — technically functional, deployment-unsuitable. |

## 19. Evidence Gaps

| ID | Gap | Nature | Blocking? |
|---|---|---|---|
| G-01 | No production certificate fingerprint is documented anywhere (repo, CI, or reports) | **Absence of evidence by design** — no production keystore has ever been created for this project | Yes — must be created in a controlled manner in the next phase (Phase 5.7) |
| G-02 | APK `versionCode=2018` vs pubspec build 18 | CI builder's `flutter.versionCode` mapping detail | No — metadata hygiene |
| G-03 | No Play App Signing / store deployment configuration exists | Outside project scope so far | No — only relevant when a store distribution channel is decided |

## 20. Release Blocking Matrix

| Condition | Status |
|---|---|
| Exact approved artifact identified | ✔ (sizes/SHA-256 match) |
| Artifact belongs to b9b4120 | ✔ (headSha exact) |
| Artifact belongs to CI run 32314746960 | ✔ (verified via GitHub API) |
| APK signature cryptographically verifies | ✔ ("Verifies", v1+v2) |
| Certificate fingerprint extracted | ✔ (SHA-256 `72ef2fb0…74f7`) |
| Certificate is **not** debug | ✘ — it is the debug certificate |
| Production fingerprint established | ✘ — none exists |
| APK fingerprint == production fingerprint | ✘ — no production reference to compare against |
| applicationId == com.hotburger.hot_burger | ✔ |
| versionName == 3.9.0 | ✔ |
| build == 18 (via versionCode) | ✘ — observed `2018` (G-02) |
| No signing fallback ambiguity | ✘ — release path = debug keys, no production alternative |

One critical production-identity condition failing is sufficient; all three production-identity conditions fail here.

## 21. Final Decision

```
PHASE 5.6.1 FINAL DECISION

DECISION:
SIGNING NOT VERIFIED — RELEASE HANDOFF BLOCKED
Classification: SIGNING NOT VERIFIED — DEBUG CERTIFICATE

BASELINE:
b9b4120

CI:
32314746960

APPLICATION ID:
com.hotburger.hot_burger

VERSION:
3.9.0 (versionName) — versionCode observed 2018 (see G-02)

APK:
EXACT APPROVED ARTIFACT (provenance verified byte-for-byte)

SIGNATURE:
CRYPTOGRAPHICALLY VALID — but signed with the Android auto-generated
debug certificate (CN=Android Debug, serial 1, valid 2026–2056)

CERTIFICATE FINGERPRINT (SHA-256):
72ef2fb0de290d3a69b561039a9c82ce9b80e8d5f152a07bba37467b9d6d74f7
(all three ABIs — identical, single signer, single builder)

PRODUCTION CERTIFICATE:
DOES NOT EXIST IN REPOSITORY OR CI — no keystore, no fingerprint,
no secret wiring, no Play upload identity

SOURCE/CI/ARTIFACT/SIGNING CHAIN:
CHAIN VERIFIED, TERMINAL NODE = DEBUG KEY

P0: 0 | P1: 1 (SI-F-01) | P2: 1 (SI-F-02) | P3: 0
RELEASE SIGNING BLOCKER: 1 (debug-signed release APK)

FILES MODIFIED: 0
PRODUCTION MODIFIED: NO
TESTS MODIFIED: NO
CI MODIFIED: NO
SCHEMA/MIGRATION MODIFIED: NO
APK REBUILT: NO
APK RESIGNED: NO
COMMIT: NO
PUSH: NO
```

What is **NOT** in question: the code is frozen and verified (Health 98/100 from prior phases), the build is genuine, the provenance is intact, and the APK's own financial/reporting logic is unchanged. What **is** blocked: production deployment trust. Releasing this artifact to a store or to customers as a "production" build would ship with a signing identity that is neither owner-controlled nor consistent across device installs and store upgrades.

The remediation path (out of scope for this READ-ONLY phase, to be executed in **Phase 5.7** under explicit owner direction) is: create a production keystore in a controlled manner (stored outside the repo, referenced via gitignored `key.properties`), wire `signingConfigs.release` in `android/app/build.gradle`, and re-run the approved build (same commit `b9b4120` — no code change needed) to produce a production-signed artifact. The current code needs zero modification; only the signing identity does.

## 22. Safety Footer

```
==========================================================
SAFETY CONFIRMATIONS
==========================================================
Production Code Modified = NO
Tests Modified = NO
Database Modified = NO
Schema Modified = NO
Migrations Modified = NO
CI Configuration Modified = NO
APK Rebuilt = NO
APK Re-signed = NO
APK Altered = NO (READ-ONLY inspection only; original artifact untouched)
Commit = NO
Push = NO
Tag = NO
Release = NO
Signing Operation Performed = NO
Sensitive Material Disclosed = NO
==========================================================
VERDICT: SIGNING NOT VERIFIED — RELEASE HANDOFF BLOCKED
(SIGNING NOT VERIFIED — DEBUG CERTIFICATE)
AWAITING PHASE 5.7 — PRODUCTION SIGNING SETUP
==========================================================
STOP.
```
