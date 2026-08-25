import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/data/local_reminder_store.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  test('lastShownAt returns null when nothing has been recorded for the key', () async {
    final store = LocalReminderStore(FakeSecureKeyValueStore());
    expect(await store.lastShownAt('daily_mission:2026-08-25'), isNull);
  });

  test('recordShown then lastShownAt round-trips the exact instant', () async {
    final store = LocalReminderStore(FakeSecureKeyValueStore());
    final shownAt = DateTime(2026, 8, 25, 9, 15, 30);

    await store.recordShown('daily_mission:2026-08-25', shownAt);
    final loaded = await store.lastShownAt('daily_mission:2026-08-25');

    expect(loaded, shownAt);
  });

  test('different dedup keys are stored independently — recording one never '
      'clobbers another', () async {
    final store = LocalReminderStore(FakeSecureKeyValueStore());
    await store.recordShown('daily_mission:2026-08-25', DateTime(2026, 8, 25, 9));
    await store.recordShown('mission_followup:mi-1', DateTime(2026, 8, 25, 14));

    expect(await store.lastShownAt('daily_mission:2026-08-25'), DateTime(2026, 8, 25, 9));
    expect(await store.lastShownAt('mission_followup:mi-1'), DateTime(2026, 8, 25, 14));
  });

  test('recording again for the same key overwrites the previous value', () async {
    final store = LocalReminderStore(FakeSecureKeyValueStore());
    await store.recordShown('mission_followup:mi-1', DateTime(2026, 8, 25, 6));
    await store.recordShown('mission_followup:mi-1', DateTime(2026, 8, 25, 12));

    expect(await store.lastShownAt('mission_followup:mi-1'), DateTime(2026, 8, 25, 12));
  });
}
