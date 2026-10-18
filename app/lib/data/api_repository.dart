import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/format.dart';
import 'models.dart';
import 'payday_schedule.dart';
import 'repository.dart';

/// Talks to the Laravel API (`backend/`), authenticating with a Sanctum token.
class ApiRepository implements PairnestRepository {
  ApiRepository(String baseUrl, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) options.headers['Authorization'] = 'Bearer $_token';
          handler.next(options);
        },
      ),
    );
  }

  static const _tokenKey = 'pairnest_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _token;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List ? first.first.toString() : first.toString();
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return "Can't reach Pairnest right now. Check your connection.";
    }
    return 'Something went wrong (${e.response?.statusCode ?? 'network'}).';
  }

  // Secure storage needs HTTPS on web; over plain HTTP the session simply
  // isn't remembered between page loads instead of failing to sign in.
  Future<String?> _readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistToken(String? token) async {
    try {
      token == null ? await _storage.delete(key: _tokenKey) : await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Keep the in-memory token only.
    }
  }

  Future<Me> _startSession(Response<dynamic> res) async {
    _token = res.data['token'] as String;
    await _persistToken(_token);
    return Me.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  Future<Me> _me() async {
    final res = await _dio.get('auth/me');
    return Me.fromJson(res.data['user'] as Map<String, dynamic>);
  }

  @override
  Future<Me?> restoreSession() async {
    _token = await _readToken();
    if (_token == null) return null;
    try {
      return await _me();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _token = null;
        await _persistToken(null);
        return null;
      }
      throw Exception(_message(e));
    }
  }

  @override
  Future<({Me me, String recoveryKey})> start(String name, OnboardingProfile profile) => _call(() async {
    final res = await _dio.post('auth/start', data: {'name': name.trim(), 'profile': profile.toJson()});
    return (me: await _startSession(res), recoveryKey: res.data['recovery_key'] as String);
  });

  @override
  Future<Me> recover(String recoveryKey) =>
      _call(() async => _startSession(await _dio.post('auth/recover', data: {'recovery_key': recoveryKey.trim()})));

  @override
  Future<Me> redeemRelink(String code) =>
      _call(() async => _startSession(await _dio.post('auth/relink/redeem', data: {'code': code.trim()})));

  @override
  Future<({String code, DateTime expiresAt, String forName})> relinkCode() => _call(() async {
    final data = (await _dio.post('auth/relink')).data as Map<String, dynamic>;
    return (
      code: data['code'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String).toLocal(),
      forName: (data['for'] ?? '') as String,
    );
  });

  @override
  Future<Me> uploadAvatar(Uint8List bytes, String filename) => _call(() async {
    final form = FormData.fromMap({'photo': MultipartFile.fromBytes(bytes, filename: filename)});
    final res = await _dio.post('me/avatar', data: form);
    return Me.fromJson(res.data['user'] as Map<String, dynamic>);
  });

  @override
  Future<Me> removeAvatar() => _call(() async => Me.fromJson((await _dio.delete('me/avatar')).data['user'] as Map<String, dynamic>));

  @override
  Future<Uint8List?> avatar(int userId) async {
    try {
      final res = await _dio.get<List<int>>('members/$userId/avatar', options: Options(responseType: ResponseType.bytes));
      return res.data == null ? null : Uint8List.fromList(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_message(e));
    }
  }

  @override
  Future<String> newRecoveryKey() => _call(() async => (await _dio.post('auth/recovery-key')).data['recovery_key'] as String);

  @override
  Future<void> logout() async {
    try {
      await _dio.post('auth/logout');
    } on DioException {
      // Token may already be invalid; still clear it locally.
    }
    _token = null;
    await _persistToken(null);
  }

  @override
  Future<Me> createNest(String theme) => _call(() async {
    await _dio.post('couple', data: {'theme': theme});
    return _me();
  });

  @override
  Future<Me> joinNest(String code) => _call(() async {
    await _dio.post('couple/join', data: {'code': code.trim()});
    return _me();
  });

  @override
  Future<void> updateTheme(String theme) => _call(() => _dio.patch('couple', data: {'theme': theme}));

  @override
  Future<Dashboard> dashboard() => _call(() async {
    return Dashboard.fromJson((await _dio.get('dashboard')).data as Map<String, dynamic>);
  });

  @override
  Future<List<FeedItem>> feed() =>
      _call(() async => [for (final f in (await _dio.get('feed')).data as List) FeedItem.fromJson(f as Map<String, dynamic>)]);

  @override
  Future<List<Txn>> transactions({DateTime? month, DateTime? from, DateTime? to, String query = ''}) => _call(() async {
    final res = await _dio.get(
      'transactions',
      queryParameters: {
        if (month != null) 'month': monthKey(month),
        if (from != null && to != null) ...{'from': dayKey(from), 'to': dayKey(to)},
        if (query.trim().isNotEmpty) 'q': query.trim(),
        // The whole period at once, so totals and filters see everything.
        'per_page': 500,
      },
    );
    return [for (final t in res.data['data'] as List) Txn.fromJson(t as Map<String, dynamic>)];
  });

  @override
  Future<Txn> addTransaction(TxnDraft d) => _call(() async {
    final res = await _dio.post('transactions', data: _txnBody(d));
    return Txn.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<Txn> updateTransaction(int id, TxnDraft d) => _call(() async {
    final res = await _dio.patch('transactions/$id', data: _txnBody(d));
    return Txn.fromJson(res.data as Map<String, dynamic>);
  });

  static Map<String, dynamic> _txnBody(TxnDraft d) => {
    'type': d.type,
    'amount': d.amount,
    'category': d.category,
    'title': d.title,
    'payment_method': d.paymentMethod,
    'is_split': d.isSplit,
    'occurred_on': dayKey(d.occurredOn),
    if (d.paidBy != null) 'user_id': d.paidBy,
    'wallet_id': d.walletId,
  };

  @override
  Future<void> deleteTransaction(int id) => _call(() => _dio.delete('transactions/$id'));

  @override
  Future<BudgetSummary> budget(DateTime month) =>
      _call(() async => BudgetSummary.fromJson((await _dio.get('budgets/${monthKey(month)}')).data as Map<String, dynamic>));

  @override
  Future<BudgetSummary> saveBudget(DateTime month, double total, Map<String, double> limits) => _call(() async {
    final res = await _dio.put(
      'budgets/${monthKey(month)}',
      data: {
        'total': total,
        'lines': [
          for (final e in limits.entries) {'category': e.key, 'limit_amount': e.value},
        ],
      },
    );
    return BudgetSummary.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<List<Goal>> goals() =>
      _call(() async => [for (final g in (await _dio.get('goals')).data as List) Goal.fromJson(g as Map<String, dynamic>)]);

  @override
  Future<Goal> addGoal({required String name, String? subtitle, required String icon, required double target, DateTime? targetDate}) =>
      _call(() async {
        final res = await _dio.post(
          'goals',
          data: {
            'name': name,
            'subtitle': subtitle,
            'icon': icon,
            'target_amount': target,
            if (targetDate != null) 'target_date': dayKey(targetDate),
          },
        );
        return Goal.fromJson(res.data as Map<String, dynamic>);
      });

  @override
  Future<Goal> updateGoal(
    int id, {
    required String name,
    String? subtitle,
    required String icon,
    required double target,
    DateTime? targetDate,
  }) => _call(() async {
    final res = await _dio.patch(
      'goals/$id',
      data: {
        'name': name,
        'subtitle': subtitle,
        'icon': icon,
        'target_amount': target,
        'target_date': targetDate == null ? null : dayKey(targetDate),
      },
    );
    return Goal.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<Goal> cancelGoal(int id) => _call(() async => Goal.fromJson((await _dio.post('goals/$id/cancel')).data as Map<String, dynamic>));

  @override
  Future<Goal> restoreGoal(int id) => _call(() async => Goal.fromJson((await _dio.post('goals/$id/restore')).data as Map<String, dynamic>));

  @override
  Future<({Goal goal, int? transferId})> contribute(int goalId, double amount) => _call(() async {
    final data = (await _dio.post('goals/$goalId/contributions', data: {'amount': amount})).data as Map<String, dynamic>;
    return (goal: Goal.fromJson(data), transferId: data['transaction_id'] as int?);
  });

  @override
  Future<List<Mood>> moods() =>
      _call(() async => [for (final m in (await _dio.get('moods')).data as List) Mood.fromJson(m as Map<String, dynamic>)]);

  @override
  Future<Mood> addMood({required String mood, String? note, required bool isPrivate}) => _call(() async {
    final res = await _dio.post('moods', data: {'mood': mood, 'note': note, 'is_private': isPrivate});
    return Mood.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<TalkState> currentTalk() => _call(() async => TalkState.fromJson((await _dio.get('talks/current')).data as Map<String, dynamic>));

  @override
  Future<TalkState> answerTalk(String answer) => _call(
    () async => TalkState.fromJson((await _dio.post('talks/current/answer', data: {'answer': answer})).data as Map<String, dynamic>),
  );

  @override
  Future<List<PastTalk>> talkHistory() =>
      _call(() async => [for (final t in (await _dio.get('talks/history')).data as List) PastTalk.fromJson(t as Map<String, dynamic>)]);

  @override
  Future<List<Bill>> bills() =>
      _call(() async => [for (final b in (await _dio.get('bills')).data as List) Bill.fromJson(b as Map<String, dynamic>)]);

  @override
  Future<Bill> addBill(BillDraft d) =>
      _call(() async => Bill.fromJson((await _dio.post('bills', data: _billBody(d))).data as Map<String, dynamic>));

  @override
  Future<Bill> updateBill(int id, BillDraft d) =>
      _call(() async => Bill.fromJson((await _dio.patch('bills/$id', data: _billBody(d))).data as Map<String, dynamic>));

  @override
  Future<void> deleteBill(int id) => _call(() => _dio.delete('bills/$id'));

  @override
  Future<({Bill bill, int transactionId})> payBill(int id) => _call(() async {
    final data = (await _dio.post('bills/$id/pay')).data as Map<String, dynamic>;
    return (bill: Bill.fromJson(data['bill'] as Map<String, dynamic>), transactionId: (data['transaction'] as Map)['id'] as int);
  });

  @override
  Future<Bill> unpayBill(int id, {required int transactionId, required DateTime previousDue}) => _call(() async {
    final res = await _dio.post('bills/$id/unpay', data: {'transaction_id': transactionId, 'next_due_on': dayKey(previousDue)});
    return Bill.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<List<Wallet>> wallets() =>
      _call(() async => [for (final w in (await _dio.get('wallets')).data as List) Wallet.fromJson(w as Map<String, dynamic>)]);

  @override
  Future<Wallet> addWallet(WalletDraft d) => _call(() async {
    final res = await _dio.post('wallets', data: {..._walletBody(d), 'is_shared': d.isShared, 'balance': ?d.balance});
    return Wallet.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<Wallet> updateWallet(int id, WalletDraft d) =>
      _call(() async => Wallet.fromJson((await _dio.patch('wallets/$id', data: _walletBody(d))).data as Map<String, dynamic>));

  @override
  Future<void> archiveWallet(int id) => _call(() => _dio.delete('wallets/$id'));

  @override
  Future<Wallet> setWalletBalance(int id, double balance) =>
      _call(() async => Wallet.fromJson((await _dio.post('wallets/$id/balance', data: {'balance': balance})).data as Map<String, dynamic>));

  static Map<String, dynamic> _walletBody(WalletDraft d) => {
    'name': d.name,
    'kind': d.kind,
    'provider': d.provider,
    'last4': d.last4,
    'show_balance_to_partner': d.showBalanceToPartner,
  };

  @override
  Future<List<Payday>> paydays() =>
      _call(() async => [for (final d in (await _dio.get('paydays')).data as List) Payday.fromJson(d as Map<String, dynamic>)]);

  @override
  Future<Payday> addPayday(PaydayDraft d) =>
      _call(() async => Payday.fromJson((await _dio.post('paydays', data: _paydayBody(d))).data as Map<String, dynamic>));

  @override
  Future<Payday> updatePayday(int id, PaydayDraft d) =>
      _call(() async => Payday.fromJson((await _dio.patch('paydays/$id', data: _paydayBody(d))).data as Map<String, dynamic>));

  @override
  Future<void> deletePayday(int id) => _call(() => _dio.delete('paydays/$id'));

  @override
  Future<({Payday payday, int transactionId})> receivePayday(int id, {double? amount}) => _call(() async {
    final data = (await _dio.post('paydays/$id/receive', data: {'amount': ?amount})).data as Map<String, dynamic>;
    return (payday: Payday.fromJson(data['payday'] as Map<String, dynamic>), transactionId: (data['transaction'] as Map)['id'] as int);
  });

  @override
  Future<Payday> unreceivePayday(int id, {required int transactionId, required DateTime previousNext}) => _call(() async {
    final res = await _dio.post('paydays/$id/unreceive', data: {'transaction_id': transactionId, 'next_on': dayKey(previousNext)});
    return Payday.fromJson(res.data as Map<String, dynamic>);
  });

  static Map<String, dynamic> _paydayBody(PaydayDraft d) => {
    'title': d.title,
    'amount': d.amount,
    'frequency': d.frequency,
    if (isByDay(d.frequency)) 'days': d.days else 'next_on': dayKey(d.nextOn!),
    'is_split': d.isSplit,
  };

  @override
  Future<SplitBalance> balance() => _call(() async => SplitBalance.fromJson((await _dio.get('balance')).data as Map<String, dynamic>));

  @override
  Future<Settlement> settleUp({required double amount, required int fromUserId}) => _call(() async {
    final res = await _dio.post('settlements', data: {'amount': amount, 'from_user_id': fromUserId});
    return Settlement.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<void> deleteSettlement(int id) => _call(() => _dio.delete('settlements/$id'));

  static Map<String, dynamic> _billBody(BillDraft d) => {
    'title': d.title,
    'amount': d.amount,
    'category': d.category,
    'frequency': d.frequency,
    'next_due_on': dayKey(d.nextDueOn),
    'is_split': d.isSplit,
  };

  @override
  Future<List<Plan>> plans() =>
      _call(() async => [for (final p in (await _dio.get('plans')).data as List) Plan.fromJson(p as Map<String, dynamic>)]);

  @override
  Future<Plan> addPlan({required String kind, required String title, String? notes, DateTime? scheduledAt, int? goalId}) => _call(() async {
    final res = await _dio.post(
      'plans',
      data: {'kind': kind, 'title': title, 'notes': notes, 'scheduled_at': scheduledAt?.toUtc().toIso8601String(), 'goal_id': goalId},
    );
    return Plan.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<void> deletePlan(int id) => _call(() => _dio.delete('plans/$id'));
}
