const String kSdkPlatform = 'flutter';
const String kSdkVersion = '0.2.0';

const String kDefaultEndpoint = 'https://edge.adpluga.com';

const Duration kServeTimeout = Duration(milliseconds: 3000);
const Duration kTrackTimeout = Duration(milliseconds: 5000);
const int kRetryMaxAttempts = 2;
const Duration kRetryBaseBackoff = Duration(milliseconds: 200);

const double kViewabilityThreshold = 0.5;
const Duration kViewabilityDwell = Duration(milliseconds: 1000);
const Duration kViewabilityTick = Duration(milliseconds: 200);

const Duration kFeaturesRevalidate = Duration(minutes: 5);

const Duration kTelemetryFlushInterval = Duration(minutes: 5);
const int kTelemetryFlushOnCount = 100;
const int kTelemetryLatencySampleCap = 128;
const int kTelemetryMaxEventsPerBatch = 256;

const String kHeaderSdkKey = 'X-AdPluga-Key';
const String kHeaderSdkPlatform = 'X-Adpluga-Sdk-Platform';
const String kHeaderSdkVersion = 'X-Adpluga-Sdk-Version';
const String kHeaderIfNoneMatch = 'If-None-Match';
const String kHeaderMinSdk = 'X-Adpluga-Min-Sdk';
