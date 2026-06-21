import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/features/ads/data/admin_ads_repository.dart';

void main() {
  test('seed contains researched web and mobile ad slots', () {
    final data = AdSettingsData.seed();
    final keys = data.slots.map((slot) => slot.key).toSet();

    expect(data.slotsFor(AdPlatform.web), hasLength(22));
    expect(data.slotsFor(AdPlatform.mobile), hasLength(19));
    expect(data.adsensePublisherId, 'ca-pub-6674987005803282');
    expect(
      keys,
      containsAll([
        'web_home_top',
        'web_home_below_hero',
        'web_home_feed_inline',
        'web_category_feed_inline',
        'web_home_sidebar',
        'web_home_sidebar_end',
        'web_home_left_rail',
        'web_side_rail_left',
        'web_side_rail_right',
        'web_article_top',
        'web_news_incontent',
        'web_article_end',
        'web_home_billboard',
        'web_home_section_break',
        'web_article_after_media',
        'web_article_midcontent',
        'web_article_sidebar',
        'web_article_related_before',
        'web_video_feed_inline',
        'web_story_between',
        'web_search_results_inline',
        'web_profile_sidebar',
        'mobile_home_top',
        'mobile_home_after_market',
        'mobile_feed_inline',
        'mobile_feed_rectangle',
        'mobile_detail_incontent',
        'mobile_detail_between_articles',
        'mobile_video_feed_inline',
        'mobile_anchor',
        'mobile_interstitial',
        'mobile_home_after_hero',
        'mobile_category_after_masthead',
        'mobile_category_feed_inline',
        'mobile_detail_after_media',
        'mobile_detail_midcontent',
        'mobile_detail_end',
        'mobile_video_feed_rectangle',
        'mobile_search_results_inline',
        'mobile_profile_feed_inline',
        'mobile_story_between',
      ]),
    );

    final interstitial = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_interstitial',
    );
    expect(interstitial.active, isFalse);
    expect(interstitial.fullscreen, isTrue);

    final mobileStory = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_story_between',
    );
    expect(mobileStory.active, isFalse);

    final homeTop = data.slots.firstWhere((slot) => slot.key == 'web_home_top');
    expect(
      homeTop.creatives.first.imageUrl,
      '/local-upload/image/2026-06-19/pateez_728x90_reklam.gif',
    );

    final mobileRectangle = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_feed_rectangle',
    );
    expect(
      mobileRectangle.creatives.first.imageUrl,
      '/local-upload/image/2026-06-19/pateez_336x280_reklam.gif',
    );

    final mobileHomeTop = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_home_top',
    );
    expect(
      mobileHomeTop.creatives.first.imageUrl,
      '/local-upload/image/2026-06-19/pateez_728x90_reklam.gif',
    );

    final homeTopAdsense = homeTop.creatives.firstWhere(
      (creative) => creative.id == 'ad_web_home_top_adsense',
    );
    expect(homeTopAdsense.adsenseSlotId, '8185130828');

    final mobileFeedAdsense = data.slots
        .firstWhere((slot) => slot.key == 'mobile_feed_inline')
        .creatives
        .firstWhere(
          (creative) => creative.id == 'ad_mobile_feed_inline_adsense',
        );
    expect(mobileFeedAdsense.adsenseSlotId, '2549660768');

    final inactiveInterstitial = data.slots.firstWhere(
      (slot) => slot.key == 'mobile_interstitial',
    );
    expect(inactiveInterstitial.active, isFalse);
    expect(inactiveInterstitial.creatives.first.adsenseSlotId, isEmpty);
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
      data.slots.any((slot) => slot.key == 'mobile_detail_midcontent'),
      true,
    );
    expect(data.slots.last.key, 'web_custom_partner');
  });
}
