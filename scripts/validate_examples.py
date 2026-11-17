#!/usr/bin/env python3
"""Validate example documents in examples/ against the JSON Schemas in src/schemas/.

The example-to-schema mapping lives in scripts/example-schema-mapping.yaml.
Every *.json file under examples/ must be accounted for there, either under
`mappings` (validated) or `no_schema` (explicitly excused, with a reason).

Exit code is non-zero if any example fails validation against its schema, if
a mapping entry points at a file that doesn't exist, or if an example file
exists that isn't listed anywhere in the mapping.
"""
from __future__ import annotations

import json
import sys
import warnings
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import url2pathname

# RefResolver is deprecated in favor of the `referencing` library, but its
# base_uri semantics are exactly what's needed to resolve the relative
# `$ref`s between files in src/schemas/ against their file:// location.
warnings.filterwarnings("ignore", category=DeprecationWarning, message=".*RefResolver.*")

import yaml
from jsonschema import Draft7Validator, FormatChecker, RefResolver

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_ROOT = ROOT / "src"
EXAMPLES_ROOT = ROOT / "examples"
MAPPING_FILE = ROOT / "scripts" / "example-schema-mapping.yaml"


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def uri_to_path(uri: str) -> Path:
    parsed = urlparse(uri)
    return Path(url2pathname(parsed.path))


def yaml_ref_handler(uri: str):
    return load_yaml(uri_to_path(uri))


def validator_for_schema(schema_path: Path) -> Draft7Validator:
    schema = load_yaml(schema_path)
    resolver = RefResolver(
        base_uri=schema_path.resolve().as_uri(),
        referrer=schema,
        handlers={"file": yaml_ref_handler},
    )
    return Draft7Validator(schema, resolver=resolver, format_checker=FormatChecker())


def main() -> int:
    mapping = load_yaml(MAPPING_FILE)
    mappings = mapping.get("mappings", [])
    no_schema = mapping.get("no_schema", [])

    all_examples = sorted(p.relative_to(EXAMPLES_ROOT).as_posix() for p in EXAMPLES_ROOT.rglob("*.json"))
    accounted_for: set[str] = set()

    problems: list[str] = []
    failures: list[str] = []
    invalid_count = 0

    for entry in no_schema:
        rel = entry["path"]
        accounted_for.add(rel)
        if not (EXAMPLES_ROOT / rel).is_file():
            problems.append(f"no_schema entry points at a missing file: examples/{rel}")

    for entry in mappings:
        schema_rel = entry["schema"]
        schema_path = SCHEMA_ROOT / schema_rel
        if not schema_path.is_file():
            problems.append(f"mapping entry points at a missing schema: src/{schema_rel}")
            continue

        try:
            validator = validator_for_schema(schema_path)
        except Exception as exc:  # noqa: BLE001 - report and continue
            problems.append(f"could not load schema src/{schema_rel}: {exc}")
            continue

        for example_rel in entry["examples"]:
            accounted_for.add(example_rel)
            example_path = EXAMPLES_ROOT / example_rel
            if not example_path.is_file():
                problems.append(f"mapping entry points at a missing example: examples/{example_rel}")
                continue

            with example_path.open("r", encoding="utf-8") as f:
                instance = json.load(f)

            errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
            if errors:
                invalid_count += 1
                failures.append(f"\nINVALID: examples/{example_rel}  (schema: src/{schema_rel})")
                for e in errors:
                    loc = "/".join(str(x) for x in e.path) or "<root>"
                    failures.append(f"  - at [{loc}]: {e.message}")
            else:
                print(f"OK      examples/{example_rel}  (schema: src/{schema_rel})")

    unaccounted = [e for e in all_examples if e not in accounted_for]
    for rel in unaccounted:
        problems.append(
            f"examples/{rel} is not listed in scripts/example-schema-mapping.yaml "
            "(add it under `mappings` with its schema, or under `no_schema` with a reason)"
        )

    if failures:
        print("\n".join(failures))

    if problems:
        print("\nMapping problems:")
        for p in problems:
            print(f"  - {p}")

    if failures or problems:
        print(f"\n{invalid_count} example(s) failed validation; {len(problems)} mapping problem(s).")
        return 1

    print(f"\nAll {len(all_examples)} example files validated successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
