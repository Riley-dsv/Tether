# Tether

Tether is a local-first mobile workspace designed to help people with Dissociative Identity Disorder (DID) communicate with their alters or parts and coordinate everyday life together.

The app provides a shared place for conversations, handovers, tasks, reminders, and important information. It is built around cooperation rather than control: no member is treated as the primary identity, authorship may be left unknown or collective, and edits remain visible in the history.

> [!IMPORTANT]
> Tether is an organizational and communication tool. It does not diagnose DID, replace professional care, or provide emergency support.

## Principles

- **No primary identity:** every member is represented equally.
- **Optional attribution:** a message can be written as a member, multiple people, or an unknown author.
- **No silent rewriting:** editing and deletion preserve historical context.
- **Clear sharing boundaries:** content identifies whether it is private, shared with a group, or visible in the common space.
- **Local ownership:** application data is stored locally in SQLite.
- **Cooperation, not surveillance:** activity history to explain what happened.

## Current features

### Members and identity

- Create and rename internal member profiles.
- Archive members without destroying their historical contributions.
- Choose who is writing when a message is sent.
- Use an unknown or collective sender when nobody knows who is present.

### Conversations and targeted sharing

- Use a general conversation shared by all active members.
- Create persistent conversations for one or more specific members.
- Distinguish private, group, and shared spaces.
- Transfer information from one conversation to another while retaining context.

### Messages

- Send and read messages in shared or targeted conversations.
- Search message content.
- Pin important messages.
- Mark messages as read and see acknowledgement information.
- Load long conversations incrementally with pagination.
- Edit messages through revisions rather than overwriting their history.
- Delete messages using historical tombstones rather than silently removing them.

### Handovers

Handovers make important information available to one or more recipients. A handover can contain:

- a summary;
- recipients and a priority level;
- completed and outstanding items;
- supporting context;
- an optional expiration time;
- read receipts.

### Tasks and reminders

- Create tasks with descriptions, deadlines, and reminder information.
- Assign a task to one or several members.
- Mark a task as available to **anyone**, avoiding forced ownership.
- Track task status and completion.
- Link relevant task activity to the system log.

### Home and system log

The home screen provides an immediate overview of unread messages, important handovers, tasks due today, and the next scheduled item.

The system log is a cross-cutting history of meaningful activity, such as a task being created, a handover being read, or an appointment changing. Purely technical events can be hidden.

## Privacy and data safety

Tether persists its data in a local SQLite database. Message revision bodies are encrypted at rest with authenticated AES-256-GCM encryption. The encryption key is generated on the device and kept outside SQLite using the operating system's secure storage. Existing plaintext message revisions are encrypted when the message store is first accessed after upgrading.

Message metadata, member names, handovers, tasks, and system-log summaries are not yet encrypted. Full-database encryption and fast locking remain planned, so message encryption should not be interpreted as protection for every field in the database.

## Technology

- [Flutter](https://flutter.dev/) and Dart
- SQLite through `sqflite`
- `sqflite_common_ffi` for desktop development and tests
- Material UI components

## Project structure

The application separates persistence, domain logic, screens, and reusable widgets:

```text
lib/
├── app/        # Application composition, navigation, and dependencies
├── database/   # SQLite database, tables, and versioned migrations
├── features/   # Feature-specific models, repositories, state, and screens
├── shared/     # Reusable widgets and shared presentation code
└── main.dart   # Application entry point
```

The precise folders inside each feature may vary, but UI code should remain separate from persistence and business rules. Dependencies are provided at composition boundaries instead of being created throughout the widget tree.

## Getting started

### Requirements

- Flutter SDK compatible with the version declared by the project
- Android Studio or the Android SDK for Android development
- A connected Android device or emulator

Check the local toolchain:

```bash
flutter doctor
flutter devices
```

Install dependencies and start the app:

```bash
flutter pub get
flutter run
```

## Testing

The repository includes a test runner for formatting, static analysis, unit and widget tests, integration tests, and Android build verification:

```bash
./scripts/test.sh check
./scripts/test.sh unit
./scripts/test.sh integration <device-id>
./scripts/test.sh all <device-id>
./scripts/test.sh build
```

The integration device can also be supplied through an environment variable:

```bash
DEVICE_ID=<device-id> ./scripts/test.sh integration
```

Use `flutter devices` to find the identifier of a connected phone or emulator.

## API documentation

Public contracts and non-obvious invariants use Dartdoc `///` comments. Generate
the browsable API reference with:

```bash
dart doc
```

The generated site is written to `doc/api/` and is intentionally ignored by
Git. Broader architectural invariants are documented in `doc/architecture.md`.

## Continuous integration

The GitHub Actions workflow in `.github/workflows/ci.yml` checks formatting and analysis, runs the automated test suites, verifies an Android build, and exercises the integration suite on an Android emulator.

## Known limitations and roadmap

The project is under active development. Important future work includes:

- encryption for non-message content and metadata;
- fast locking and secure unlock flows;
- native scheduled notifications for reminders;
- fuller calendar and event support;
- backup and recovery that preserve local ownership and privacy;
- accessibility and performance testing across more Android devices.

## Contributing

Contributions are welcome when they preserve Tether's core principles. In particular:

- do not introduce a privileged “main” member;
- do not require every action to be attributed to a specific member;
- make visibility and recipients understandable before content is sent;
- avoid features whose main purpose is surveillance or enforcement;
- handle DID and plurality with respectful language.

When changing behavior, add or update tests and run the relevant commands from `scripts/test.sh` before opening a pull request.

## Language

People use different terms for their experiences, including *alters*, *parts*, *members*, and *system members*. Tether uses neutral language where possible and aims to let each system choose the terms that feel right for them.
