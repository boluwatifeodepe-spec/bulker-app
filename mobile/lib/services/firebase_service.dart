import 'package:bulker/models/contact.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  bool get isAvailable => Firebase.apps.isNotEmpty || _auth != null || _firestore != null;

  FirebaseAuth? get _safeAuth {
    if (_auth != null) return _auth;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  FirebaseFirestore? get _safeFirestore {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  Future<User?> signInAnonymously() async {
    final auth = _safeAuth;
    if (auth == null) return null;
    final current = auth.currentUser;
    if (current != null) return current;
    return (await auth.signInAnonymously()).user;
  }

  CollectionReference<Map<String, dynamic>>? contactsRef() {
    final auth = _safeAuth;
    final firestore = _safeFirestore;
    final uid = auth?.currentUser?.uid;
    if (uid == null || firestore == null) {
      if (!isAvailable) return null;
      throw StateError('User must be authenticated before reading contacts');
    }
    return firestore.collection('users').doc(uid).collection('contacts');
  }

  Stream<List<Contact>> watchContacts() {
    final ref = contactsRef();
    if (ref == null) return Stream<List<Contact>>.value(const []);
    return ref.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Contact.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> upsertContact(Contact contact) {
    final ref = contactsRef();
    if (ref == null) return Future<void>.value();
    return ref.doc(contact.id).set(contact.toJson());
  }

  Future<void> deleteContact(String id) {
    final ref = contactsRef();
    if (ref == null) return Future<void>.value();
    return ref.doc(id).delete();
  }
}
