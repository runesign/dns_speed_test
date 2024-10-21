import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class DnsServer {
  final String type;
  final String address;

  DnsServer({required this.type, required this.address});

  factory DnsServer.fromJson(Map<String, dynamic> json) {
    return DnsServer(
      type: json['type'],
      address: json['address'],
    );
  }
}

class DnsProvider {
  final String name;
  final List<DnsServer> servers;
  final String region;

  DnsProvider({
    required this.name,
    required this.servers,
    required this.region,
  });

  factory DnsProvider.fromJson(Map<String, dynamic> json) {
    return DnsProvider(
      name: json['name'],
      servers: (json['servers'] as List)
          .map((server) => DnsServer.fromJson(server))
          .toList(),
      region: json['region'],
    );
  }
}

Future<List<DnsProvider>> loadDnsProviders() async {
  final String response =
      await rootBundle.loadString('assets/dns_providers.json');
  final List<dynamic> data = json.decode(response);
  return data.map((item) => DnsProvider.fromJson(item)).toList();
}

Future<Duration> testDoHLatency(String dohUrl) async {
  final stopwatch = Stopwatch()..start();
  try {
    await http.get(Uri.parse(dohUrl));
  } catch (e) {
    print('DoH request failed: $e');
  }
  stopwatch.stop();
  return stopwatch.elapsed;
}

Future<Duration> testTraditionalDNSLatency(
    String ipAddress, InternetAddressType type) async {
  final stopwatch = Stopwatch()..start();
  try {
    final domain = '${DateTime.now().microsecondsSinceEpoch}.netlify.com';
    final addresses = await InternetAddress.lookup(
      domain,
      type: type,
    );

    if (addresses.isNotEmpty) {
      stopwatch.stop();
      return stopwatch.elapsed;
    }
  } catch (e) {
    print('Traditional DNS request failed: $e');
  }

  stopwatch.stop();
  return const Duration(seconds: 3);
}

Future<Duration> testDnsLatency(DnsServer server) async {
  if (server.type == 'doh') {
    return await testDoHLatency(server.address);
  } else {
    final type = server.type == 'ipv4'
        ? InternetAddressType.IPv4
        : InternetAddressType.IPv6;
    return await testTraditionalDNSLatency(server.address, type);
  }
}

class DnsService {
  Future<Duration> testServer(DnsServer server) async {
    return await testDnsLatency(server);
  }
}

class WebDnsService {
  Future<Duration> testServer(DnsServer server) async {
    if (server.type == 'doh') {
      return await testDnsLatency(server);
    } else {
      throw UnsupportedError(
          'Traditional DNS testing is not supported in web environments.');
    }
  }
}
