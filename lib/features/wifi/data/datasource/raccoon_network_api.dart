import 'dart:convert';
import 'dart:io';

class RaccoonNetworkApi {
  RaccoonNetworkApi({this.baseUrl = 'http://localhost:8421'});

  final String baseUrl;

  Future<List<dynamic>> getNetworks() async {
    return await _requestList('GET', '/api/v1/network/networks');
  }

  Future<void> connect(Map<String, dynamic> payload) async {
    await _requestMap('POST', '/api/v1/network/connect', body: payload);
  }

  Future<void> forget(String ssid) async {
    await _requestMap(
        'POST', '/api/v1/network/forget/${Uri.encodeComponent(ssid)}');
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    return await _requestMap('GET', '/api/v1/network/device-info');
  }

  Future<String> getNetworkMode() async {
    final data = await _requestMap('GET', '/api/v1/network/mode');
    return data['mode'] as String;
  }

  Future<void> setNetworkMode(String mode) async {
    await _requestMap('PUT', '/api/v1/network/mode', body: {'mode': mode});
  }

  Future<Map<String, dynamic>?> getAccessPointConfig() async {
    return await _requestMap('GET', '/api/v1/network/access-point/config',
        allowEmpty: true);
  }

  Future<Map<String, dynamic>> startAccessPoint(
      Map<String, dynamic> payload) async {
    return await _requestMap('POST', '/api/v1/network/access-point/start',
        body: payload);
  }

  Future<void> stopAccessPoint() async {
    await _requestMap('POST', '/api/v1/network/access-point/stop');
  }

  Future<Map<String, dynamic>> getAccessPointStatus() async {
    return await _requestMap('GET', '/api/v1/network/access-point/status');
  }

  Future<String> findBestWifiBand() async {
    final data =
        await _requestMap('GET', '/api/v1/network/access-point/best-band');
    return data['band'] as String;
  }

  Future<int> findBestChannel(String band) async {
    final data = await _requestMap(
      'GET',
      '/api/v1/network/access-point/best-channel?band=${Uri.encodeQueryComponent(band)}',
    );
    return data['channel'] as int;
  }

  Future<Map<String, dynamic>> scanAccessPointChannels(String band) async {
    return await _requestMap(
      'GET',
      '/api/v1/network/access-point/channel-scan?band=${Uri.encodeQueryComponent(band)}',
    );
  }

  Future<List<dynamic>> getSavedNetworks() async {
    return await _requestList('GET', '/api/v1/network/saved');
  }

  Future<void> saveNetwork(Map<String, dynamic> payload) async {
    await _requestMap('PUT', '/api/v1/network/saved', body: payload);
  }

  Future<void> removeSavedNetwork(String ssid) async {
    await _requestMap(
        'DELETE', '/api/v1/network/saved/${Uri.encodeComponent(ssid)}');
  }

  Future<Map<String, dynamic>?> getSavedNetwork(String ssid) async {
    return await _requestMap(
      'GET',
      '/api/v1/network/saved/${Uri.encodeComponent(ssid)}',
      allowEmpty: true,
    );
  }

  Future<void> enableLanOnlyMode() async {
    await _requestMap('POST', '/api/v1/network/lan/enable');
  }

  Future<void> disableLanOnlyMode() async {
    await _requestMap('POST', '/api/v1/network/lan/disable');
  }

  Future<Map<String, dynamic>> getLanStatus() async {
    return await _requestMap('GET', '/api/v1/network/lan/status');
  }

  Future<Map<String, dynamic>> _requestMap(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool allowEmpty = false,
  }) async {
    final client = HttpClient();
    try {
      final request = await _open(client, method, path);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw Exception(_decodeError(responseBody));
      }
      if (responseBody.isEmpty && allowEmpty) {
        return {};
      }
      if (responseBody.isEmpty) {
        return {};
      }
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<List<dynamic>> _requestList(String method, String path) async {
    final client = HttpClient();
    try {
      final request = await _open(client, method, path);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw Exception(_decodeError(responseBody));
      }
      if (responseBody.isEmpty) {
        return const [];
      }
      return jsonDecode(responseBody) as List<dynamic>;
    } finally {
      client.close();
    }
  }

  Future<HttpClientRequest> _open(
      HttpClient client, String method, String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await switch (method) {
      'GET' => client.getUrl(uri),
      'POST' => client.postUrl(uri),
      'PUT' => client.putUrl(uri),
      'DELETE' => client.deleteUrl(uri),
      _ => throw UnsupportedError('Unsupported method: $method'),
    };
    request.headers.set('X-API-Token', await _token());
    return request;
  }

  Future<String> _token() async {
    final tokenFile = File('/home/pi/.raccoon/api_token');
    return (await tokenFile.readAsString()).trim();
  }

  String _decodeError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}
    return responseBody.isEmpty ? 'Unknown network error' : responseBody;
  }
}
