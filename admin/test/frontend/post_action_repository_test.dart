import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/features/home/data/post_action_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('recordView sends stable viewer id and maps live view count', () async {
    SharedPreferences.setMockInitialValues({});
    Map<String, Object?>? requestBody;

    final repository = PostActionRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/post-action');
        requestBody = _decodeBody(request);
        return http.Response(
          jsonEncode(_statePayload(145)),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await repository.recordView(
      postId: '42',
      source: 'poll_vote',
    );

    expect(requestBody?['action'], 'view');
    expect(requestBody?['postId'], '42');
    expect(requestBody?['source'], 'poll_vote');
    expect(requestBody?['viewerId'], isA<String>());
    expect((requestBody?['viewerId'] as String).length, greaterThan(8));
    expect(state.views, 145);
  });

  test('recordVideoView sends invisible video view metrics', () async {
    SharedPreferences.setMockInitialValues({
      'pateeznews_mobile_viewer_id': 'viewer-test-1234',
    });
    Map<String, Object?>? requestBody;

    final repository = PostActionRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        requestBody = _decodeBody(request);
        return http.Response(
          jsonEncode(_statePayload(146)),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await repository.recordVideoView(
      postId: '42',
      videoUrl: 'https://example.com/video.mp4',
      source: 'video',
      watchedSeconds: 30,
      durationSeconds: 75,
      thresholdSeconds: 30,
    );

    expect(requestBody?['action'], 'video_view');
    expect(requestBody?['postId'], '42');
    expect(requestBody?['viewerId'], 'viewer-test-1234');
    expect(requestBody?['videoUrl'], 'https://example.com/video.mp4');
    expect(requestBody?['watchedSeconds'], 30);
    expect(requestBody?['durationSeconds'], 75);
    expect(requestBody?['thresholdSeconds'], 30);
    expect(state.views, 146);
  });
}

Map<String, Object?> _decodeBody(http.Request request) {
  final decoded = jsonDecode(request.body);
  expect(decoded, isA<Map>());
  return (decoded as Map).map(
    (key, value) => MapEntry(key.toString(), value as Object?),
  );
}

Map<String, Object?> _statePayload(int views) => {
  'ok': true,
  'counts': {
    'likes': 12,
    'dislikes': 1,
    'shares': 4,
    'views': views,
    'saves': 5,
  },
  'userState': {'liked': false, 'disliked': false, 'saved': false},
};
