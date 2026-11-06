# Uberon pin and full-Uberon QC

DHBAO uses one pinned Uberon release for three things:

- **The bridge.** `sources/uberon-bridge-to-dhba.owl` is downloaded from that release's tag in the Uberon repo and merged into `components/all_templates.owl`.
- **The Uberon import.** `mirror-uberon` downloads that release's `uberon-base.owl` and removes its disjointness axioms. This becomes part of `imports/merged_import.owl`.
- **The full-Uberon QC.** `make reason_test_uberon` reasons over `dhbao-edit.owl` together with that release's **full** `uberon.owl`. Unlike the import, the full release keeps the disjointness axioms, and it is what CL's release reasons with. CI runs it on every PR.

The release is set in one place, `src/ontology/dhbao.Makefile`:

```make
UBERON_RELEASE = 2026-11-05
```

Pinning means a new Uberon release can't change the import or fail a PR. Uberon only changes when someone deliberately bumps `UBERON_RELEASE`.

## What the check catches

The DHBA–Uberon mappings are not kept in this repo. They are `xref: DHBA:<id>` lines in Uberon's `uberon-edit.obo`. Uberon turns each one into an axiom in `uberon-bridge-to-dhba.owl`:

```
DHBA_x EquivalentTo (UBERON_y and (in_taxon some Homo sapiens))
```

The bridge is merged into `components/all_templates.owl` when the component is built. Two kinds of error then show up only when DHBA is reasoned together with Uberon:

- **Unsatisfiable classes.** A DHBA structure sits under a parent whose Uberon mapping is a region that Uberon says the structure is *not* in. For example, DHBA puts the posterior commissure in *white matter of midbrain*, while Uberon puts it in the diencephalon, and Uberon has *part of midbrain* disjoint with *part of diencephalon*.
- **Inferred equivalences between named classes.** Two DHBA classes are mapped to the same Uberon class, so they become equivalent to each other. CL's release fails on these (`--equivalent-classes-allowed asserted-only`). This is what blocked CL's import refresh in November 2026 (obophenotype/uberon#3815).

The standard `make test` doesn't catch either: the import has no disjointness axioms, and `reason_test` allows inferred equivalences.

## The known-inconsistency list

DHBA classes that are already inconsistent with full Uberon are listed in `src/ontology/qc_known_inconsistent_full_uberon.txt`. Each line is either the IRI of an unsatisfiable class, or `IRI == IRI` for an inferred equivalence. The header of the list names the Uberon release it was generated for.

`make reason_test_uberon` fails if any of these happen:

| Condition | What to do |
|---|---|
| A class or equivalence that isn't in the list is reported | Fix the mapping that causes it (see "Explaining a reported line" below). Don't add it to the list. |
| A listed line no longer applies | Remove the line from the list in the same PR. A stale line keeps the class exempt, so if it breaks again the check won't notice. |
| The list's header names a different release from `UBERON_RELEASE` | Regenerate the list (see "Bumping the Uberon release" below). |

Rules for the list:

- **Never add a line by hand.** Lines are only added when the list is regenerated during an Uberon bump, and each new line has to be explained in that PR.
- **Removing lines by hand is fine.** Removing a line is how you record a fix.
- The aim is to shrink the list to nothing. Each fix should remove lines.

## Fixing a listed inconsistency

Most fixes are made in Uberon, not here:

1. Fix the mapping in Uberon (`src/ontology/uberon-edit.obo`): remove or move the `xref: DHBA:<id>`, or fix the Uberon axiom that is wrong. Reference the DHBA issue in the Uberon PR.
2. Once that change is in a Uberon release, bump `UBERON_RELEASE` here and rebuild the component with that release's bridge (see below). The regenerated list no longer has the fixed lines. Link the DHBA issue from that PR so it closes.

If a fix reaches DHBA without an Uberon bump, for example a change to the structure graph, remove the fixed lines from the list by hand in the same PR. The check fails until you do.

## Everyday PRs

- **CI checks the committed `components/all_templates.owl` and `imports/merged_import.owl` (`COMP=false`).** It doesn't rebuild the component from the Allen API or download the bridge.
- **To run the check locally:**

  ```sh
  cd src/ontology
  sh run.sh make reason_test_uberon IMP=false PAT=false MIR=false COMP=false
  ```

  The first run downloads the full Uberon file (about 96 MB) to `tmp/uberon-<release>.owl`. Later runs reuse it.

## Explaining a reported line

Unsatisfiable classes:

```sh
cd src/ontology
robot merge -i dhbao-edit.owl -i tmp/uberon-$(sed -n 's/^UBERON_RELEASE *= *//p' dhbao.Makefile).owl \
  explain -M unsatisfiability --unsatisfiable all --explanation explain.md
```

Inferred equivalences: look for the Uberon term that has both DHBA IDs as xrefs:

```sh
grep -B30 -E 'xref: DHBA:(12491|12518)$' uberon-edit.obo | grep -E '^(id|name|xref: DHBA)'
```

## Bumping the Uberon release (before `refresh-imports` and every release)

Pin first, then refresh. This keeps the import, the bridge in the component, and the QC check on the same Uberon release.

1. Choose the release from <https://github.com/obophenotype/uberon/releases>, for example `v2026-11-05`. Check that it includes both `uberon-base.owl` and `uberon.owl` as release files.
2. In `src/ontology/dhbao.Makefile`, set `UBERON_RELEASE` to that release without the `v`.
3. Rebuild the component, which downloads the bridge from the same Uberon release (`https://raw.githubusercontent.com/obophenotype/uberon/v<release>/src/ontology/bridge/uberon-bridge-to-dhba.owl`), and refresh the imports. The component is built twice because the import seed depends on the component, and the component's labels depend on the import:

   ```sh
   sh run.sh make components/all_templates.owl
   sh run.sh make refresh-imports COMP=false
   sh run.sh make components/all_templates.owl
   ```

4. Regenerate the known list:

   ```sh
   sh run.sh make reason_test_uberon IMP=false PAT=false MIR=false COMP=false UBERON_QC_UPDATE=true
   ```

   This rewrites `qc_known_inconsistent_full_uberon.txt` and prints which lines it removed and which it added.
5. Review every added line. Each one is a DHBA class or equivalence that the new Uberon release made inconsistent. Explain it, then fix the mapping or open an issue for it, and link the issue in the PR. For each removed line, link the issue it fixes.
6. Open **one PR** with only the `UBERON_RELEASE` change, the rebuilt component and imports, and the regenerated list. Don't mix in other changes.
7. Run `make prepare_release` only after that PR is merged.

CI caches the downloaded `uberon.owl` with a cache key based on `UBERON_RELEASE`. Bumping the release downloads the new file once.
