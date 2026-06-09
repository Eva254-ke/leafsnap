import 'dart:async';

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'remote_config_service.dart';

class BillingState {
  const BillingState({
    required this.isAvailable,
    required this.isLoading,
    required this.products,
    this.errorMessage,
  });

  final bool isAvailable;
  final bool isLoading;
  final List<ProductDetails> products;
  final String? errorMessage;

  BillingState copyWith({
    bool? isAvailable,
    bool? isLoading,
    List<ProductDetails>? products,
    String? errorMessage,
  }) {
    return BillingState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      errorMessage: errorMessage,
    );
  }
}

class BillingService {
  BillingService._();

  static final BillingService instance = BillingService._();

  static const String _entitlementsCollection = 'entitlements';

  final InAppPurchase _iap = InAppPurchase.instance;
  final ValueNotifier<BillingState> state = ValueNotifier<BillingState>(
    const BillingState(isAvailable: false, isLoading: true, products: []),
  );
  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _entitlementSub;
  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((_) {
      _listenToEntitlements();
    });
    await _listenToEntitlements();

    final available = await _iap.isAvailable();
    state.value = state.value.copyWith(isAvailable: available, isLoading: true);

    if (!available) {
      state.value = state.value.copyWith(isLoading: false);
      return;
    }

    _purchaseSub ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        state.value = state.value.copyWith(
          errorMessage: 'Billing is unavailable right now.',
        );
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    if (!state.value.isAvailable) {
      return;
    }

    state.value = state.value.copyWith(isLoading: true, errorMessage: null);
    final response = await _iap.queryProductDetails(_productIds());

    if (response.error != null) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: response.error!.message,
      );
      return;
    }

    final products = response.productDetails;
    products.sort((a, b) => a.id.compareTo(b.id));
    state.value = state.value.copyWith(
      isLoading: false,
      products: products,
    );
  }

  ProductDetails? get monthlyProduct {
    return _productById(_monthlyId());
  }

  ProductDetails? get yearlyProduct {
    return _productById(_yearlyId());
  }

  Future<void> purchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyWithServer(purchase);
          break;
        case PurchaseStatus.error:
          state.value = state.value.copyWith(
            errorMessage: purchase.error?.message ?? 'Purchase failed.',
          );
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyWithServer(PurchaseDetails purchase) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      state.value = state.value.copyWith(
        errorMessage: 'Sign in required to verify purchase.',
      );
      return;
    }

    final verificationData = purchase.verificationData.serverVerificationData;
    if (verificationData.isEmpty) {
      state.value = state.value.copyWith(
        errorMessage: 'Missing purchase token.',
      );
      return;
    }

    final baseUrl = _backendBaseUrl();
    if (baseUrl.isEmpty) {
      state.value = state.value.copyWith(
        errorMessage: 'Billing server is not configured.',
      );
      return;
    }

    try {
      final idToken = await currentUser.getIdToken(true);
      final packageInfo = await PackageInfo.fromPlatform();
      final uri = Uri.parse('$baseUrl/v1/iap/googleplay/verify');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: _encodeJson({
          'packageName': packageInfo.packageName,
          'purchaseToken': verificationData,
          'productId': purchase.productID,
          'source': purchase.verificationData.source,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        state.value = state.value.copyWith(
          errorMessage: 'Purchase verification failed.',
        );
        return;
      }
    } catch (_) {
      state.value = state.value.copyWith(
        errorMessage: 'Purchase verification failed.',
      );
    }
  }

  Future<void> _listenToEntitlements() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await _entitlementSub?.cancel();
      _entitlementSub = null;
      isPremium.value = false;
      return;
    }

    await _entitlementSub?.cancel();
    _entitlementSub = FirebaseFirestore.instance
        .collection(_entitlementsCollection)
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final active = data['active'] == true;
      final expiresAt = data['expiresAt'];
      final now = DateTime.now();
      DateTime? expiry;
      if (expiresAt is Timestamp) {
        expiry = expiresAt.toDate();
      }
      final stillActive = active && (expiry == null || expiry.isAfter(now));
      isPremium.value = stillActive;
    });
  }

  String _backendBaseUrl() {
    final rc = RemoteConfigService.instance;
    return rc.getString(RemoteConfigKeys.backendBaseUrl).trim();
  }

  String _encodeJson(Map<String, dynamic> payload) {
    return _jsonEncoder.convert(payload);
  }

  static const _jsonEncoder = JsonEncoder();

  ProductDetails? _productById(String id) {
    for (final product in state.value.products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Set<String> _productIds() {
    final ids = <String>{_monthlyId(), _yearlyId()};
    ids.removeWhere((id) => id.trim().isEmpty);
    return ids;
  }

  String _monthlyId() {
    final rc = RemoteConfigService.instance;
    final id = rc.getString(RemoteConfigKeys.androidMonthlyProductId).trim();
    // Fallback to hardcoded ID if Remote Config returns empty
    return id.isEmpty ? 'leafsnap_premium_monthly' : id;
  }

  String _yearlyId() {
    final rc = RemoteConfigService.instance;
    final id = rc.getString(RemoteConfigKeys.androidYearlyProductId).trim();
    // Fallback to hardcoded ID if Remote Config returns empty
    return id.isEmpty ? 'leafsnap_premium_yearly' : id;
  }
}
