import 'package:stpvelox/features/wifi/domain/enities/wifi_band.dart';

class WifiChannelScan {
  const WifiChannelScan({
    required this.band,
    required this.recommendedChannel,
    required this.detectedNetworks,
    required this.channels,
    required this.networks,
  });

  final WifiBand band;
  final int recommendedChannel;
  final int detectedNetworks;
  final List<WifiChannelInfo> channels;
  final List<WifiDetectedNetwork> networks;
}

class WifiChannelInfo {
  const WifiChannelInfo({
    required this.channel,
    required this.networkCount,
    required this.ssids,
    required this.isRecommended,
  });

  final int channel;
  final int networkCount;
  final List<String> ssids;
  final bool isRecommended;
}

class WifiDetectedNetwork {
  const WifiDetectedNetwork({
    required this.ssid,
    required this.channel,
    required this.frequencyMHz,
    required this.centerFrequencyMHz,
    required this.channelWidthMHz,
    required this.signalDbm,
    required this.qualityPercent,
    required this.overlapStartChannel,
    required this.overlapEndChannel,
    required this.affectedChannels,
  });

  final String ssid;
  final int channel;
  final int? frequencyMHz;
  final int? centerFrequencyMHz;
  final int? channelWidthMHz;
  final int? signalDbm;
  final int? qualityPercent;
  final int overlapStartChannel;
  final int overlapEndChannel;
  final List<int> affectedChannels;
}
