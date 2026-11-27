/// Current and historical SQL declarations used by database creation/migration.
///
/// Constants already referenced by a released migration are immutable. Fresh
/// install definitions may advance only alongside a corresponding migration.
abstract final class MessageTables {
  // CREATE TABLE definitions already used by a migration are append-only.
  // Schema changes belong in a new migration, never in historical SQL.
  static const createMembers = '''
    CREATE TABLE members (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      deleted_at TEXT,
      pin_hash TEXT,
      pin_salt TEXT,
      pin_iterations INTEGER
    )
  ''';

  static const createConversations = '''
    CREATE TABLE conversations (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL,
      scope TEXT NOT NULL DEFAULT 'group'
        CHECK (scope IN ('general', 'group'))
    )
  ''';

  static const createGeneralConversationIndex =
      "CREATE UNIQUE INDEX idx_conversations_general ON conversations(scope) WHERE scope = 'general'";

  static const generalConversationId = 'system_general';

  static const createConversationMembers = '''
    CREATE TABLE conversation_members (
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      joined_at TEXT NOT NULL,
      PRIMARY KEY (conversation_id, member_id)
    )
  ''';

  static const createMessageEntities = '''
    CREATE TABLE message_entities (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      created_at TEXT NOT NULL,
      visibility TEXT NOT NULL DEFAULT 'shared'
        CHECK (visibility IN ('private', 'group', 'shared')),
      source_message_id TEXT REFERENCES message_entities(id)
    )
  ''';

  /// Historical v3 shape. Migration definitions must not depend on the
  /// evolving current schema.
  static const createMessageEntitiesV3 = '''
    CREATE TABLE message_entities (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      created_at TEXT NOT NULL
    )
  ''';

  static const createMessageRecipients = '''
    CREATE TABLE message_recipients (
      logical_id TEXT NOT NULL REFERENCES message_entities(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      PRIMARY KEY (logical_id, member_id)
    )
  ''';

  static const createHandovers = '''
    CREATE TABLE handovers (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      author_id TEXT REFERENCES members(id),
      summary TEXT NOT NULL,
      priority TEXT NOT NULL CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
      context TEXT,
      expires_at TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const createHandoverRecipients = '''
    CREATE TABLE handover_recipients (
      handover_id TEXT NOT NULL REFERENCES handovers(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      PRIMARY KEY (handover_id, member_id)
    )
  ''';

  static const createHandoverItems = '''
    CREATE TABLE handover_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      handover_id TEXT NOT NULL REFERENCES handovers(id),
      description TEXT NOT NULL,
      is_completed INTEGER NOT NULL CHECK (is_completed IN (0, 1)),
      sort_order INTEGER NOT NULL
    )
  ''';

  static const createHandoverReceipts = '''
    CREATE TABLE handover_receipts (
      handover_id TEXT NOT NULL REFERENCES handovers(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      read_at TEXT NOT NULL,
      PRIMARY KEY (handover_id, member_id)
    )
  ''';

  static const createSystemEvents = '''
    CREATE TABLE system_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id TEXT REFERENCES conversations(id),
      actor_id TEXT REFERENCES members(id),
      event_type TEXT NOT NULL,
      summary TEXT NOT NULL,
      is_technical INTEGER NOT NULL DEFAULT 0 CHECK (is_technical IN (0, 1)),
      related_message_id TEXT REFERENCES message_entities(id),
      related_handover_id TEXT REFERENCES handovers(id),
      related_task_id TEXT REFERENCES tasks(id),
      created_at TEXT NOT NULL
    )
  ''';

  static const createTasks = '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      author_id TEXT REFERENCES members(id),
      title TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('todo', 'inProgress', 'done')),
      assignment_mode TEXT NOT NULL CHECK (assignment_mode IN ('anyone', 'specific')),
      deadline TEXT,
      reminder_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const createTaskAssignees = '''
    CREATE TABLE task_assignees (
      task_id TEXT NOT NULL REFERENCES tasks(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      PRIMARY KEY (task_id, member_id)
    )
  ''';

  static const createTaskEventIndex =
      'CREATE INDEX idx_system_events_task ON system_events(related_task_id)';

  static const createRevisions = '''
    CREATE TABLE message_revisions (
      revision_id INTEGER PRIMARY KEY AUTOINCREMENT,
      logical_id TEXT NOT NULL REFERENCES message_entities(id),
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      author_id TEXT REFERENCES members(id),
      recorded_by_id TEXT REFERENCES members(id),
      content TEXT NOT NULL,
      revision INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      supersedes_revision_id INTEGER REFERENCES message_revisions(revision_id),
      deleted_at TEXT,
      UNIQUE(logical_id, revision)
    )
  ''';

  static const createEncryptedRevisions = '''
    CREATE TABLE message_revisions (
      revision_id INTEGER PRIMARY KEY AUTOINCREMENT,
      logical_id TEXT NOT NULL REFERENCES message_entities(id),
      conversation_id TEXT NOT NULL REFERENCES conversations(id),
      author_id TEXT REFERENCES members(id),
      recorded_by_id TEXT REFERENCES members(id),
      content TEXT NOT NULL,
      content_ciphertext TEXT,
      content_nonce TEXT,
      content_mac TEXT,
      encryption_version INTEGER NOT NULL DEFAULT 0,
      revision INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      supersedes_revision_id INTEGER REFERENCES message_revisions(revision_id),
      deleted_at TEXT,
      UNIQUE(logical_id, revision)
    )
  ''';

  static const createPins = '''
    CREATE TABLE message_pins (
      logical_id TEXT PRIMARY KEY REFERENCES message_entities(id),
      pinned_by TEXT REFERENCES members(id),
      pinned_at TEXT NOT NULL
    )
  ''';

  static const createReceipts = '''
    CREATE TABLE message_receipts (
      logical_id TEXT NOT NULL REFERENCES message_entities(id),
      member_id TEXT NOT NULL REFERENCES members(id),
      seen_at TEXT NOT NULL,
      PRIMARY KEY (logical_id, member_id)
    )
  ''';

  static const indexes = [
    'CREATE INDEX idx_revisions_conversation ON message_revisions(conversation_id, logical_id, revision DESC)',
    'CREATE INDEX idx_revisions_content ON message_revisions(content COLLATE NOCASE)',
    'CREATE INDEX idx_receipts_member ON message_receipts(member_id, logical_id)',
    'CREATE INDEX idx_recipients_member ON message_recipients(member_id, logical_id)',
  ];

  static const integrityTriggers = [
    '''CREATE TRIGGER IF NOT EXISTS validate_revision_message
       BEFORE INSERT ON message_revisions
       WHEN NOT EXISTS (SELECT 1 FROM message_entities WHERE id = NEW.logical_id)
       BEGIN SELECT RAISE(ABORT, 'message entity does not exist'); END''',
    '''CREATE TRIGGER IF NOT EXISTS validate_pin_message
       BEFORE INSERT ON message_pins
       WHEN NOT EXISTS (SELECT 1 FROM message_entities WHERE id = NEW.logical_id)
       BEGIN SELECT RAISE(ABORT, 'message entity does not exist'); END''',
    '''CREATE TRIGGER IF NOT EXISTS validate_receipt_message
       BEFORE INSERT ON message_receipts
       WHEN NOT EXISTS (SELECT 1 FROM message_entities WHERE id = NEW.logical_id)
       BEGIN SELECT RAISE(ABORT, 'message entity does not exist'); END''',
    '''CREATE TRIGGER IF NOT EXISTS validate_recipient_message
       BEFORE INSERT ON message_recipients
       WHEN NOT EXISTS (SELECT 1 FROM message_entities WHERE id = NEW.logical_id)
       BEGIN SELECT RAISE(ABORT, 'message entity does not exist'); END''',
  ];
}
