import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM push-bildirishnomalar (topic-модель, token boshqaruvisiz):
/// - har login'da qurilma `cafe_{cafeId}` topic'iga,
/// - owner bo'lsa qo'shimcha `cafe_{cafeId}_owner` topic'iga obuna bo'ladi.
/// Cloud Function (notifySale) yangi chek yaratilganda owner-topic'ka yuboradi.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  String? _cafeTopic;
  String? _ownerTopic;

  /// Android 13+ / iOS: bildirishnoma ruxsatini so'raydi (bir marta).
  Future<void> requestPermission() async {
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('FCM permission failed: $e');
    }
  }

  /// Login/bootstrap'dan keyin chaqiriladi.
  Future<void> subscribeForCafe(String cafeId, {required bool isOwner}) async {
    await requestPermission();
    try {
      _cafeTopic = 'cafe_$cafeId';
      await _fm.subscribeToTopic(_cafeTopic!);
      if (isOwner) {
        _ownerTopic = 'cafe_${cafeId}_owner';
        await _fm.subscribeToTopic(_ownerTopic!);
      } else {
        _ownerTopic = null;
      }
      debugPrint('FCM subscribed: $_cafeTopic ${_ownerTopic ?? ''}');
    } catch (e) {
      debugPrint('FCM subscribe failed: $e');
    }
  }

  /// To'liq chiqishda (logout) chaqiriladi — boshqa kafening xabari kelmasin.
  Future<void> unsubscribeAll() async {
    try {
      if (_cafeTopic != null) await _fm.unsubscribeFromTopic(_cafeTopic!);
      if (_ownerTopic != null) await _fm.unsubscribeFromTopic(_ownerTopic!);
    } catch (e) {
      debugPrint('FCM unsubscribe failed: $e');
    }
    _cafeTopic = null;
    _ownerTopic = null;
  }
}
