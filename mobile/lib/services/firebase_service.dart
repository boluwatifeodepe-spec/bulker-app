import 'package:bulker/models/contact.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<User> signInAnonymously() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    return (await _auth.signInAnonymously()).user!;
  }

  CollectionReference<Map<String, dynamic>> contactsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User must be authenticated before reading contacts');
    }
    return _firestore.collection('users').doc(uid).collection('contacts');
  }

  Stream<List<Contact>> watchContacts() {
    return contactsRef().snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Contact.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> upsertContact(Contact contact) {
    return contactsRef().doc(contact.id).set(contact.toJson());
  }

  Future<void> deleteContact(String id) {
    return contactsRef().doc(id).delete();
  }
}
