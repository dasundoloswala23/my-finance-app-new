import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:telephony/telephony.dart';

import '../../../firebase_options.dart';
import '../domain/pending_sms_txn.dart';
import '../domain/sms_transaction_parser.dart';
import 'pending_sms_repository.dart';

/// Wires the `telephony` plugin to [PendingSmsRepository]: Android-only,
/// no-ops silently on every other platform so callers don't need to guard
/// every call site with a platform check.
class SmsListenerService {
  SmsListenerService._();

  static final Telephony _telephony = Telephony.instance;

  static Future<bool> hasPermission() async {
    return await _telephony.requestSmsPermissions ?? false;
  }

  static Future<bool> requestPermission() async {
    return await _telephony.requestSmsPermissions ?? false;
  }

  /// Starts listening for incoming SMS, including while the app is
  /// backgrounded. Must be called after permission has been granted.
  static void startListening() {
    _telephony.listenIncomingSms(
      onNewMessage: _handleMessage,
      onBackgroundMessage: smsBackgroundHandler,
      listenInBackground: true,
    );
  }

  static Future<void> _handleMessage(SmsMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _saveIfTransaction(uid: user.uid, message: message);
  }

  static Future<void> _saveIfTransaction({
    required String uid,
    required SmsMessage message,
  }) async {
    final body = message.body;
    if (body == null || body.isEmpty) return;

    final parsed = SmsTransactionParser.tryParse(body);
    if (parsed == null) return;

    final repository = PendingSmsRepository(FirebaseFirestore.instance, uid);
    final id = 'sms_${message.date ?? DateTime.now().millisecondsSinceEpoch}';
    await repository.add(
      PendingSmsTxn(
        id: id,
        rawBody: body,
        amountMinor: parsed.amountMinor,
        type: parsed.type,
        merchant: parsed.merchant,
        receivedAt: message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!)
            : DateTime.now(),
      ),
    );
  }
}

/// Runs in a separate headless isolate spawned by the platform when a new
/// SMS arrives while the app isn't running in the foreground.
///
/// Must stay a top-level function (see `telephony`'s requirement) and
/// re-initialise Firebase itself, since this isolate shares no state with
/// the main one.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await SmsListenerService._saveIfTransaction(uid: user.uid, message: message);
}
