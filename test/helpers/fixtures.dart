import 'dart:convert';

const String displayFixture = '''{
  "ad": {
    "id": "ad_9c0f6b3a-1d5c-4c0b-8e8a-3f1e0d2c4a01",
    "type": "image",
    "asset_url": "https://cdn.adpluga.example/creatives/ad.png",
    "click_url": "https://landing.example",
    "width": 320,
    "height": 100
  },
  "impression_url": "https://edge.adpluga.example/v1/imp?t=abc",
  "click_url": "https://edge.adpluga.example/v1/click?t=abc",
  "track_token": "eyJhbGciOi",
  "source": "house"
}''';

const String htmlFixture = '''{
  "ad": {
    "id": "ad_html_1",
    "type": "html",
    "html": "<html><body style='margin:0'><a href='https://landing.example/x'>promo</a></body></html>",
    "click_url": "https://landing.example",
    "width": 320,
    "height": 250
  },
  "impression_url": "https://edge.adpluga.example/v1/imp?t=html",
  "click_url": "https://edge.adpluga.example/v1/click?t=html",
  "track_token": "html_token",
  "source": "house"
}''';

const String videoFixture = '''{
  "ad": {
    "id": "ad_video_1",
    "type": "video",
    "video_url": "https://cdn.adpluga.example/creatives/ad.mp4",
    "click_url": "https://landing.example",
    "width": 640,
    "height": 360,
    "duration_ms": 15000
  },
  "impression_url": "https://edge.adpluga.example/v1/imp?t=vid",
  "click_url": "https://edge.adpluga.example/v1/click?t=vid",
  "track_token": "vid_token",
  "source": "house",
  "quartile_pings": {
    "start": "https://edge.adpluga.example/vast/start",
    "first_quartile": "https://edge.adpluga.example/vast/q1",
    "midpoint": "https://edge.adpluga.example/vast/q2",
    "third_quartile": "https://edge.adpluga.example/vast/q3",
    "complete": "https://edge.adpluga.example/vast/complete"
  }
}''';

const String videoRewardedFixture = '''{
  "ad": {
    "id": "ad_video_rw_1",
    "type": "video_rewarded",
    "video_url": "https://cdn.adpluga.example/creatives/rw.mp4",
    "click_url": "https://landing.example",
    "width": 640,
    "height": 360,
    "duration_ms": 30000,
    "skippable_after_ms": 5000,
    "reward_amount": 10,
    "reward_currency": "COIN"
  },
  "impression_url": "https://edge.adpluga.example/v1/imp?t=rw",
  "click_url": "https://edge.adpluga.example/v1/click?t=rw",
  "track_token": "rw_token",
  "source": "house"
}''';

String featuresFixture({bool telemetry = true}) => jsonEncode({
      'flags': {'sdk_telemetry': telemetry},
      'sdk_min_version': {'flutter': ''},
    });
