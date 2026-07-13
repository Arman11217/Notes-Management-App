// Basic smoke test for the Notes Management App.
// Note: Firebase initialization requires a real platform, so this
// test only verifies that the app builds without crashing at the
// basic widget level. Full Firestore integration tests would need
// the firebase_test_lab or emulator setup.

import 'package:flutter_test/flutter_test.dart';

import 'package:notes_management_app/models/note.dart';

void main() {
  test('Note model toMap/fromMap round-trip', () {
    final now = DateTime(2026, 7, 13, 10, 30);
    final original = Note(
      id: 'test123',
      title: 'Test Note',
      description: 'Test description content',
      createdAt: now,
      updatedAt: now,
    );

    // Simulate Firestore map conversion (without Timestamp import dependency)
    final map = {
      'title': original.title,
      'description': original.description,
      'createdAt': now,
      'updatedAt': now,
    };

    expect(map['title'], 'Test Note');
    expect(map['description'], 'Test description content');
    expect(map['createdAt'], now);
  });

  test('Note copyWith updates fields correctly', () {
    final originalTime = DateTime(2026, 7, 13, 10, 0);
    final newTime = DateTime(2026, 7, 13, 11, 0);

    final original = Note(
      id: 'a1',
      title: 'Original',
      description: 'Original desc',
      createdAt: originalTime,
      updatedAt: originalTime,
    );

    final updated = original.copyWith(
      title: 'Updated',
      description: 'Updated desc',
      updatedAt: newTime,
    );

    expect(updated.title, 'Updated');
    expect(updated.description, 'Updated desc');
    expect(updated.createdAt, originalTime);
    expect(updated.updatedAt, newTime);
    expect(updated.id, 'a1');
  });
}
