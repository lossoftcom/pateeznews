import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/frontend/features/account/data/frontend_auth_repository.dart';

/// "Giriş yapıldıktan sonra kullanıcı kendisi çıkana kadar oturum kapanmamalı"
/// güvencesinin testleri. Önbellekteki oturum, token süresi dolsa veya sunucuya
/// ulaşılamasa bile korunur; yalnızca [FrontendAuthRepository.signOut] temizler.
void main() {
  FrontendAuthSession expiredSession() => const FrontendAuthSession(
    accessToken: 'tok-123',
    tokenType: 'bearer',
    expiresAt: 1000000000, // 2001 — çoktan süresi dolmuş
    user: FrontendAuthUser(id: 'u1', email: 'a@b.com', userMetadata: {}),
  );

  const cachedProfile = FrontendProfile(
    id: 'u1',
    username: 'nasip',
    fullName: 'Nasip',
    avatarUrl: '',
    coverUrl: '',
    role: 'member',
    email: 'a@b.com',
  );

  test('süresi dolmuş oturumda otomatik çıkış YAPMAZ', () async {
    final store = _FakeStore(session: expiredSession(), profile: cachedProfile);
    final client = MockClient(
      (req) async => http.Response(
        '{"data":{"session":null,"profile":null},"error":null}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final repo = FrontendAuthRepository(
      httpClient: client,
      store: store,
      apiBaseUrl: 'http://localhost:4321',
    );

    final state = await repo.restoreSession();

    expect(state, isNotNull);
    expect(state!.session.accessToken, 'tok-123');
    expect(state.profile?.username, 'nasip');
    expect(store.cleared, isFalse);
  });

  test('ağ/sunucu hatasında bile oturum açık kalır', () async {
    final store = _FakeStore(session: expiredSession(), profile: cachedProfile);
    final client = MockClient((req) async => throw Exception('network down'));
    final repo = FrontendAuthRepository(
      httpClient: client,
      store: store,
      apiBaseUrl: 'http://localhost:4321',
    );

    final state = await repo.restoreSession();

    expect(state, isNotNull);
    expect(state!.session.accessToken, 'tok-123');
    expect(store.cleared, isFalse);
  });

  test('hiç oturum yoksa null döner ve temizleme tetiklenmez', () async {
    final store = _FakeStore(session: null, profile: null);
    final client = MockClient((req) async => http.Response('{}', 200));
    final repo = FrontendAuthRepository(
      httpClient: client,
      store: store,
      apiBaseUrl: 'http://localhost:4321',
    );

    final state = await repo.restoreSession();

    expect(state, isNull);
    expect(store.cleared, isFalse);
  });
}

class _FakeStore extends FrontendAuthStore {
  _FakeStore({this.session, this.profile});

  FrontendAuthSession? session;
  FrontendProfile? profile;
  bool cleared = false;

  @override
  Future<FrontendAuthSession?> readSession() async => session;

  @override
  Future<void> saveSession(FrontendAuthSession value) async {
    session = value;
  }

  @override
  Future<FrontendProfile?> readProfileCache(
    String Function(String) resolveAvatarUrl,
  ) async => profile;

  @override
  Future<void> saveProfileCache(FrontendProfile value) async {
    profile = value;
  }

  @override
  Future<void> clearAuth() async {
    cleared = true;
    session = null;
    profile = null;
  }

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> clearProfileCache() async {}
}
