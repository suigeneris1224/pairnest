import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/data/api_repository.dart';

/// Answers each path with a canned status and JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, (int, Object?)> routes;
  final seen = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add('${options.method} ${options.path} ${options.headers['Authorization'] ?? '-'}');
    final (status, body) = routes[options.path] ?? (404, {'message': 'Not found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = {'id': 1, 'name': 'Alex', 'couple': null};
  const base = 'http://api.test/api/v1';

  test('a token rejected mid-session signs out instead of leaving errors behind', () async {
    final adapter = _FakeAdapter({
      'auth/recover': (200, {'token': '1|pn_abc', 'user': user}),
      'dashboard': (401, {'message': 'Unauthenticated.'}),
    });
    var signedOut = 0;
    final repo = ApiRepository(base, adapter: adapter, onSignedOut: () => signedOut++);

    await repo.recover('KEY');
    await expectLater(repo.dashboard(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(signedOut, 1);

    // The forgotten token isn't sent again, and a second 401 doesn't re-fire.
    await expectLater(repo.dashboard(), throwsA(isA<ApiException>()));
    expect(signedOut, 1);
    expect(adapter.seen.last, 'GET dashboard -');
  });

  test('a wrong recovery key is an error, not a sign-out', () async {
    final adapter = _FakeAdapter({
      'auth/recover': (
        422,
        {
          'message': 'Invalid',
          'errors': {
            'recovery_key': ["That recovery key doesn't match any nest."],
          },
        },
      ),
    });
    var signedOut = 0;
    final repo = ApiRepository(base, adapter: adapter, onSignedOut: () => signedOut++);
    await expectLater(repo.recover('NOPE'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains("doesn't match"))));
    expect(signedOut, 0);
  });

  test('server errors never show their details', () async {
    final repo = ApiRepository(
      base,
      adapter: _FakeAdapter({
        'auth/recover': (500, {'message': 'SQLSTATE[HY000]: General error: 1 no such table: users'}),
      }),
    );
    await expectLater(repo.recover('KEY'), throwsA(isA<ApiException>().having((e) => e.message, 'message', isNot(contains('SQL')))));
  });

  test('devices come back with which one is this phone', () async {
    final adapter = _FakeAdapter({
      'auth/recover': (200, {'token': '1|pn_abc', 'user': user}),
      'auth/devices': (
        200,
        [
          {'id': 7, 'relinked': true, 'current': false, 'created_at': '2026-10-27T10:00:00Z', 'last_used_at': null},
          {'id': 3, 'relinked': false, 'current': true, 'created_at': '2026-10-01T10:00:00Z', 'last_used_at': '2026-10-28T09:00:00Z'},
        ],
      ),
    });
    final repo = ApiRepository(base, adapter: adapter);
    await repo.recover('KEY');
    final devices = await repo.devices();
    expect([for (final d in devices) (d.id, d.relinked, d.current)], [(7, true, false), (3, false, true)]);
  });
}
