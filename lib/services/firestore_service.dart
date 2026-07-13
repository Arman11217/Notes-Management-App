import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';


class FirestoreService {
  final CollectionReference _notesCollection =
      FirebaseFirestore.instance.collection('notes');


  Future<String> addNote({
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Title cannot be empty.');
    }

    final now = DateTime.now();
    final noteData = {
      'title': title.trim(),
      'description': description.trim(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await _notesCollection.add(noteData);
    return docRef.id;
  }


  Stream<List<Note>> getNotesStream() {
    return _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<List<Note>> getNotesOnce() async {
    final snapshot = await _notesCollection
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Note.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<Note?> getNoteById(String id) async {
    final doc = await _notesCollection.doc(id).get();
    if (!doc.exists) return null;
    return Note.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String description,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('Title cannot be empty.');
    }

    await _notesCollection.doc(id).update({
      'title': title.trim(),
      'description': description.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }
}
