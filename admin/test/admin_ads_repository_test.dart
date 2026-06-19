import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/features/ads/data/admin_ads_repository.dart';

void main() {
  test('seed contains researched web and mobile ad slots', () {
    final data = AdSettingsData.seed();
    final keys = data.slots.map((slot) => slot.key).toSet();

    expect(data.slotsFor(AdPlatform.web), hasLength(11));
    expect(data.slotsFor(AdPlatform.mobile), hasLength(8));
    expect(
      keys,
      containsAll([
        'web_home_top',
        'web_home_below_hero',
        'web_home_feed_inline',
        'web_category_feed_inline',
        'web_home_sidebar',
        'web_home_left_rail',
        'web_side_rail_left',
        'web_side_rail_right',
        'web_article_top',
        'web_news_incontent',
        'web_article_end',
        'mobile_home_after_market',
        'mobile_feed_inline',
        'mobile_feed_rectangle',
        'mobile_detail_incontent',
        'mobile_detail_between_articles',
        'mobile_video_feed_inline',
        'mobile_anchor',
        'mobile_interstitial',
      ]),
    );

    final interstitial = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_interstitial',
    );
    expect(interstitial.active, isFalse);
    expect(interstitial.fullscreen, isTrue);
  });

  test('fromJson preserves existing slots and appends missing defaults', () {
    final data = AdSettingsData.fromJson({
      'masterEnabled': true,
      'adsenseConnected': false,
      'adsensePublisherId': 'ca-pub-test',
      'localEnabled': true,
      'slots': [
        {
          'id': 'custom_home_top',
          'key': 'web_home_top',
          'name': 'Ozel ust alan',
          'description': 'Mevcut kullanici ayari',
          'platform': 'web',
          'width': 970,
          'height': 90,
          'active': false,
          'creatives': [],
        },
        {
          'id': 'custom_slot',
          'key': 'web_custom_partner',
          'name': 'Ozel partner alani',
          'description': 'Kullanici tarafindan eklenen alan',
          'platform': 'web',
          'width': 300,
          'height': 250,
          'creatives': [],
        },
      ],
    });

    final homeTop = data.slots.firstWhere((slot) => slot.key == 'web_home_top');
    expect(homeTop.id, 'custom_home_top');
    expect(homeTop.name, 'Ozel ust alan');
    expect(homeTop.active, isFalse);

    expect(
      data.slots.any((slot) => slot.key == 'mobile_detail_incontent'),
      true,
    );
    expect(data.slots.last.key, 'web_custom_partner');
  });
}
