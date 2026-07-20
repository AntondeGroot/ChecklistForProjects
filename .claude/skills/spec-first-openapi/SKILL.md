---
name: spec-first-openapi
description: >-
  Use when working with an OpenAPI-driven codebase — editing the spec, generating client/
  server models, wiring the codegen CI gate, or debugging why a generated type or validation
  is missing. Enforces spec-as-single-source-of-truth: lint the spec structurally BEFORE
  codegen (a green codegen build does NOT prove a valid contract), make generated-DTO
  nullability honest, delete hand-written DTOs that duplicate generated ones, and close the
  spec-vs-server gap with a contract test.
---

# Spec-first OpenAPI

The spec is the **single source of truth**. Models are generated from it; hand-written DTOs
that duplicate generated ones are deleted (they drift). The traps below all built **green**
in practice — a passing codegen build is not evidence of a valid or matching contract.

## 1. Lint the spec structurally BEFORE the codegen build

`openapi-generator` and swagger-parser are lenient by design — they pass structurally broken
specs and emit silently-wrong output. Add a lint gate that runs **before** codegen.

- **Use Redocly (`recommended`), not Spectral, as the structural gate.** Redocly's `struct`
  rule validates schema objects against the OpenAPI meta-schema and catches what a green
  build hides. Spectral's default `spectral:oas` does **not** catch these (unknown keywords
  pass as valid JSON-Schema annotations). They're complementary — Spectral uniquely catches
  `oas3-unused-component` — but if you run one structural gate, run Redocly.
- **Pin the major** (`@redocly/cli@2`, not `@latest`) so a new major's rule changes can't
  turn CI red on an untouched spec.

Failure modes that build green but Redocly catches:

- Invalid schema keywords (`min`/`max` instead of `minLength`/`minimum`) → **ignored**, no
  validation annotation generated.
- A malformed inline response schema (a bare `sessionId:` under `schema:` with no
  `type`/`$ref`) → generates an **empty model**.
- A media-type typo (`appplication/json`) → accepted as a valid *custom* media type, so the
  response body binds to **nothing**. (Note: a linter can't fully catch this — see §4.)

## 2. `nullable` in OpenAPI 3.1 is silently ignored

3.1 removed the `nullable` keyword, so `nullable: true` generates as a plain non-null field.
`struct` flags it. The correct union is `type: [string, 'null']` — **but** with
openapi-generator's **Spring** generator that union produces `JsonNullable<T>`, which changes
the Java type and breaks hand-written call sites. So:

- Field is **merely optional** (not explicitly nullable) → use plain `type: string` and leave
  it **out of `required`**. Cleaner than the union.
- Field is **explicitly nullable** → use the `type: [T, 'null']` union and handle
  `JsonNullable<T>` at call sites.

## 3. Make generated-DTO nullability honest

Once the generated model package is under NullAway's `AnnotatedPackages`, its annotations
bind your call sites — so a wrong contract is *enforced*. Two common Spring-generator
mismatches:

- **A genuinely-optional response field left in `required`** generates as a `@NonNull`
  constructor arg — you can't pass the `null` you return at runtime. Remove it from `required`
  → it becomes a clean `@Nullable` wither.
- **Optional container fields (maps/arrays) default to `@NonNull` empty collections.** Set
  `<containerDefaultToNull>true</containerDefaultToNull>` in `configOptions` so non-required
  containers are `@Nullable` — this matches reality *and* keeps the wire format omitting them
  rather than emitting `{}`/`[]`.

A shared spec regenerates the **client** too — re-run the client's type-check after either
change.

## 4. Close the gap a linter cannot: codegen + contract test

A linter proves the spec is **well-formed**; it cannot prove the spec **matches the running
server** (the media-type typo in §1 slips past both linters because the key is free-form
text). Close it structurally:

1. Generate models from the spec.
2. Compile the **server against the generated interfaces** (so a drifted signature fails to
   compile).
3. Assert **real endpoint responses** — status code *and* body shape — in an integration
   test. This is what catches "spec says X, server returns Y".

## 5. Do NOT commit generated code — ignore-and-regenerate

**This project's chosen model: gitignore the generated code.** The spec is then the only
source of truth and drift is impossible by construction — there's no committed copy to fall
out of sync. Regenerate it in the build (`generate` runs before `compile`).

Consequences to get right:

- **There is no `git diff --exit-code` drift gate.** With the generated code gitignored, that
  gate is a **no-op that protects nothing** (a gitignored path never shows in the diff). If
  one exists, **delete it** rather than leave it implying a guarantee it doesn't provide.
- The real gates in this model are **spec-lint + regenerate-before-build** (§1) and the
  **contract test** (§4) — those, not a committed-code diff, are what catch problems.
- Still **delete hand-written DTOs that duplicate generated models** — the spec owns those
  types.
- Make sure the generated path is actually in `.gitignore` *and* that codegen runs on a clean
  checkout in CI (no developer's stale local copy masking a spec break).

(The alternative — commit-and-diff — is a valid model elsewhere, but it's explicitly **not**
used here; don't reintroduce a committed generated tree.)

## 6. Tune lint warnings honestly — don't blanket-disable, don't fabricate

- `operation-4xx-response` is high-value (surfaces real undocumented error responses) but
  false-positives on no-input list endpoints that only return 200. **Fix the real gaps; scope
  the genuine exceptions to `.redocly.lint-ignore.yaml` with a comment** rather than turning
  the rule off (a global off hides the real bugs it found).
- `security-defined` → turn **off** for an API with no auth by design (its `error` severity
  fails the build once per operation). Remember OpenAPI security schemes are **declarative
  only** — they document/hint codegen, they enforce nothing. Adding a scheme without
  server-side enforcement (Spring Security / a filter) is the easy half only.
- `info-license` → **off** for an unlicensed hobby/internal project; don't claim terms the
  repo doesn't have.
- `no-server-example.com` (also fires on `localhost`) → fix with a **relative server URL**
  (`url: /`, same origin — also the right `basePath` for a generated SPA client); document
  the dev URL in prose.

## CI ordering

```
redocly lint  →  generate code  →  compile (server against generated interfaces)  →  test (incl. contract test)
```

Lint first (cheap, catches malformations); regenerate; then the compile + contract test catch
spec-vs-server drift.

## Related skills

- Wiring the lint/codegen-diff gate as a ratchet on an existing spec → **`ratchet-quality-gates`**.
- The contract/integration test itself → **`incremental-tests`**.