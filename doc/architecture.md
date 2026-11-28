# Architecture and invariants

Tether is a local-first Flutter application. Its code is divided into four
layers:

- `app` is the composition root and owns concrete dependencies;
- `database` owns SQLite creation and ordered, append-only migrations;
- `features` contains domain models, store contracts, repositories, and state;
- `shared` contains presentation models and reusable widgets.

## Identity

A nullable member identifier means that attribution is unknown or deliberately
unspecified. It never refers to a synthetic “Unknown” database member. Code must
not invent a primary member or require attribution where the domain permits an
anonymous action.

Authentication, attribution, session isolation, authorization, and credential
recovery are governed by the normative
[security invariants](security-invariants.md). Architecture changes touching
those concerns must preserve that contract and its automated tests.

## Message history

`message_entities` contains the stable logical identity of a message.
`message_revisions` is append-only: edits and deletions create a new revision.
Callers must never update an earlier revision in place. Deletion revisions keep
the relationship graph while exposing no message body.

## Visibility

Visibility and conversation membership are separate checks. A member must have
access to the conversation and, for targeted messages, be the author or an
explicit recipient. Shared messages may be read without attributing the viewer.

Widgets do not grant visibility. Production stores are wrapped by
session-bound application services that validate requested member identifiers
against the active authenticated session. Repository queries remain responsible
for object-level filtering, providing a second enforcement boundary.

## Encryption

Every non-deletion message revision is encrypted independently with AES-256-GCM.
The logical message ID and revision number are authenticated as associated data,
so ciphertext cannot be moved between revisions. The master key is stored
outside SQLite. Searches decrypt only rows already selected by access-control
filters and compare their content in memory.

Member PINs are profile access gates, not encryption keys. They must not be used
as message keys or treated as a replacement for platform/device security. New
PIN verifiers use versioned Argon2id parameters and unique random salts. Legacy
PBKDF2 verifiers are upgraded only after successful authentication.

## Database migrations

Migration target versions are unique and strictly increasing. Historical table
definitions and migrations are immutable after release. A new schema change
must be represented by a new migration and by the current fresh-install schema.

## Generating API documentation

Run:

```bash
dart doc
```

Generated HTML is written to `doc/api/` and should not be committed.
