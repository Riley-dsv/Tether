# Security invariants

This document is a normative architecture contract for Tether. Changes to
authentication, attribution, persistence, messaging, logs, search, recovery,
notifications, or application lifecycle handling must preserve these rules.
Tests should exercise the invariant at the lowest meaningful boundary and, when
applicable, through the integrated workspace flow.

The words **must**, **must not**, and **cannot** describe requirements rather
than current implementation details.

## Security boundary

A member PIN authenticates access to one internal member profile. It is not the
SQLite encryption key, the message-encryption key, an operating-system account,
or protection against a compromised device. Message bodies remain protected at
rest by the separate authenticated-encryption system.

Unknown and collective attribution describe who is associated with an action;
they are not security principals. A nullable member identifier represents
Unknown and must never resolve to a synthetic member row.

## Domain and identity

- Unknown must not own, create, update, import, or restore credentials.
- Reserved attribution-only identities, including Unknown and Collective, must
  not be persisted as credential-owning members.
- Collective attribution must not authenticate any member in the collective.
- Only an individual, active member may become an authenticated principal.
- Archived members must not open new sessions, even when a stale object or
  previously valid PIN is presented.
- Members created before PIN support must remain readable and selectable. Their
  next selection may offer PIN setup, and choosing **Later** must remain valid.

## Authentication

- A correct PIN may grant access only to its associated active member.
- An incorrect PIN must not create or extend a member session.
- Changing an existing PIN requires successful verification of the current PIN.
- Failed-attempt state must be persisted so process or application restarts do
  not reset throttling.
- The failure budget must be global across members. Switching identities must
  not provide additional attempts.
- Concurrent requests must be serialized or updated atomically so they cannot
  lose failure counts or grant access after the limit is reached.
- Authentication failures must not record the supplied PIN in logs, errors, or
  analytics.

## Session isolation

- Activating a different member must revoke every capability issued to the
  previous member.
- Switching to Unknown must revoke member-specific and private access.
- A protected session that exceeds the configured background timeout must lock
  before protected content is shown again.
- Locking must close transient protected routes. Back navigation must not reopen
  a route authorized by an expired session.
- Locking or switching identities must invalidate outstanding loads and clear
  cached viewer-scoped plaintext, searches, recipients, unread state, tasks,
  handovers, and system-log projections.
- Protected screens should use a generation-bound session lease when state can
  outlive the navigation action that opened them.

## Authorization

- Widgets may request an identity or render an authorized projection, but they
  must never grant permission. Application-layer services must bind requested
  member identifiers to the active session, and repositories must independently
  enforce object visibility.
- An arbitrary member identifier supplied by a caller is not proof of
  authentication. Reads must fail closed to the anonymous projection and
  mutations must be rejected when the active session does not own that member.
- Conversation membership and content visibility are independent checks.
- Search must filter authorized rows before decrypting or comparing content.
  Unauthorized content must not affect results, counts, or snippets.
- System-log events related to messages, handovers, or tasks must inherit the
  visibility of the related object.
- Revision history and deletion tombstones must apply the same authorization as
  the current message projection.
- Notification previews must use generic text unless the intended viewer may
  read the related content.
- A transfer must verify access to its source before copying or decrypting its
  content. Access to the destination alone is insufficient.
- Edit, delete, pin, receipt, and other message mutations must authorize the
  related message, not merely the containing conversation.
- Unknown may read shared content where the product explicitly permits it, but
  must not gain targeted or member-private visibility.

### Indirect projections

Protected content must not be disclosed through a secondary feature:

- search results must not contain excerpts or matches from unauthorized rows;
- home summaries must not expose protected counts, titles, or scheduled items;
- system logs must not expose protected content, activity summaries, or private
  conversation titles;
- notification previews must remain generic until the current session is
  authorized;
- forwarding must authorize both the source and destination;
- revision history and tombstones must use the current message's visibility;
- exports must not include protected workspace data without an explicitly
  authorized, encrypted export design.

## Platform privacy

- Android production windows must use `FLAG_SECURE` so screenshots, screen
  recording, and the recents/overview snapshot cannot capture decrypted
  content.
- Android operating-system backup must remain disabled unless a future backup
  format provides explicit encryption, authorization, integrity verification,
  and safe restoration semantics.
- Platform privacy controls are defense in depth. They do not replace session
  validation or repository authorization.

## Credential persistence and recovery

- A PIN must never be stored in plaintext.
- Each credential must use an independently generated salt. Equal PINs must not
  produce equal stored verifiers.
- PIN derivation must use the recorded work factor and constant-time verifier
  comparison. Expensive derivation must not block the UI isolate.
- Database migrations must preserve existing verifier, salt, and work-factor
  values exactly unless an explicit authenticated credential upgrade is being
  performed.
- Logs, exceptions, backups, and exported diagnostics must not contain PIN
  values.
- Credential backups may contain salted verifiers, salts, and work factors, but
  never plaintext PINs.
- Credential restoration must be transactional, validate encoding and work
  factors, and target existing real member rows only.
- Backup and restoration must preserve archived state and must not manufacture
  an authenticatable Unknown or Collective identity.

## Required verification

Security-sensitive changes must retain automated coverage for:

- attribution and identity invariants;
- correct, incorrect, throttled, restarted, and concurrent authentication;
- session switching, lifecycle timeout, route closure, and cache clearing;
- search, logs, revisions, tombstones, notifications, and transfers;
- plaintext exclusion, salt uniqueness, migrations, log redaction, and
  backup/restoration.

Do not weaken or delete a security test solely to accommodate a new feature.
When an invariant intentionally changes, update this document, the relevant
architecture decision, and the tests in the same review.
