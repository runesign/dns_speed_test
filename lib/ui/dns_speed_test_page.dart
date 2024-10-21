import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../logic/dns_speed_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DnsSpeedTestPage extends StatefulWidget {
  final SharedPreferences prefs;

  DnsSpeedTestPage({required this.prefs});

  @override
  _DnsSpeedTestPageState createState() => _DnsSpeedTestPageState();
}

class _DnsSpeedTestPageState extends State<DnsSpeedTestPage> {
  late Future<List<DnsProvider>> dnsProviders;
  final Map<String, Duration> testResults = {};
  final Set<String> favorites = Set<String>();
  bool onlyFavorites = false;
  String sortBy = 'latency';
  String filterBy = 'all';
  String filterRegion = 'all';

  @override
  void initState() {
    super.initState();
    dnsProviders = loadDnsProviders();
    if (kIsWeb) {
      filterBy = 'doh'; // 在Web端默认选择DoH
    }
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() {
      onlyFavorites = widget.prefs.getBool('onlyFavorites') ?? false;
      filterBy = widget.prefs.getString('filterBy') ?? filterBy; // 使用默认值
      filterRegion = widget.prefs.getString('filterRegion') ?? 'all';
      favorites.addAll(widget.prefs.getStringList('favorites') ?? []);
    });

    // Load test results from SharedPreferences
    final testResultsJson = widget.prefs.getString('testResults');
    if (testResultsJson != null) {
      final Map<String, dynamic> testResultsMap = json.decode(testResultsJson);
      testResultsMap.forEach((key, value) {
        testResults[key] = Duration(milliseconds: value);
      });
    }
  }

  Future<void> _savePrefs() async {
    await widget.prefs.setBool('onlyFavorites', onlyFavorites);
    await widget.prefs.setString('filterBy', filterBy);
    await widget.prefs.setString('filterRegion', filterRegion);
    await widget.prefs.setStringList('favorites', favorites.toList());

    // Save test results to SharedPreferences
    final Map<String, int> testResultsMap = {};
    testResults.forEach((key, value) {
      testResultsMap[key] = value.inMilliseconds;
    });
    await widget.prefs.setString('testResults', json.encode(testResultsMap));
  }

  Future<void> startTest(DnsServer server) async {
    try {
      final Duration result = kIsWeb
          ? await WebDnsService().testServer(server)
          : await DnsService().testServer(server);
      setState(() {
        testResults['${server.type}:${server.address}'] = result;
      });
      _savePrefs();
    } catch (e) {
      if (kIsWeb && server.type != 'doh') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.webClientLimitationMessage)),
        );
      }
    }
  }

  void toggleFavorite(String serverKey) {
    setState(() {
      if (favorites.contains(serverKey)) {
        favorites.remove(serverKey);
      } else {
        favorites.add(serverKey);
      }
    });
    _savePrefs();
  }

  void setSortBy(String value) {
    setState(() {
      sortBy = value;
    });
  }

  void setFilterBy(String value) {
    if (kIsWeb && value != 'doh') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.webClientLimitationMessage)),
      );
      return;
    }
    setState(() {
      filterBy = value;
    });
    _savePrefs();
  }

  void setFilterRegion(String? value) {
    if (value != null) {
      setState(() {
        filterRegion = value;
      });
      _savePrefs();
    }
  }

  void toggleOnlyFavorites() {
    setState(() {
      onlyFavorites = !onlyFavorites;
    });
    _savePrefs();
  }

  Future<void> testAllServers(Future<List<DnsProvider>> providersFuture) async {
    final providers = await providersFuture;
    for (var provider in providers) {
      for (var server in provider.servers) {
        if ((filterBy == 'all' || server.type == filterBy) &&
            (filterRegion == 'all' || provider.region == filterRegion)) {
          await startTest(server);
        }
      }
    }
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.copyToClipboard)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dnsTest),
        actions: [
          IconButton(
            icon: Icon(Icons.star),
            color: onlyFavorites ? Colors.yellow : null,
            onPressed: toggleOnlyFavorites,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                Text('Region: '),
                DropdownButton<String>(
                  value: filterRegion,
                  onChanged: setFilterRegion,
                  items:
                      ['all', 'auto', 'us', 'eu', 'asia'].map((String choice) {
                    return DropdownMenuItem<String>(
                      value: choice,
                      child: Text(choice.toUpperCase()),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<DnsProvider>>(
        future: dnsProviders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context)!.noProvidersFound));
          } else {
            List<DnsProvider> providers = snapshot.data!;
            List<DnsServer> allServers =
                providers.expand((provider) => provider.servers).toList();

            if (filterBy != 'all') {
              allServers = allServers
                  .where((server) => server.type == filterBy)
                  .toList();
            }

            if (filterRegion != 'all') {
              allServers = allServers
                  .where((server) =>
                      providers
                          .firstWhere(
                              (provider) => provider.servers.contains(server))
                          .region ==
                      filterRegion)
                  .toList();
            }

            if (onlyFavorites) {
              allServers = allServers
                  .where((server) =>
                      favorites.contains('${server.type}:${server.address}'))
                  .toList();
            }

            allServers.sort((a, b) {
              final aLatency =
                  testResults['${a.type}:${a.address}']?.inMilliseconds ??
                      double.infinity;
              final bLatency =
                  testResults['${b.type}:${b.address}']?.inMilliseconds ??
                      double.infinity;
              return aLatency.compareTo(bLatency);
            });

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FilterButton(
                        label: 'ALL',
                        selected: filterBy == 'all',
                        onPressed: () => setFilterBy('all'),
                      ),
                      FilterButton(
                        label: 'IPv4',
                        selected: filterBy == 'ipv4',
                        onPressed: () => setFilterBy('ipv4'),
                      ),
                      FilterButton(
                        label: 'IPv6',
                        selected: filterBy == 'ipv6',
                        onPressed: () => setFilterBy('ipv6'),
                      ),
                      FilterButton(
                        label: 'DoH',
                        selected: filterBy == 'doh',
                        onPressed: () => setFilterBy('doh'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: allServers.length,
                    itemBuilder: (context, index) {
                      final server = allServers[index];
                      final serverKey = '${server.type}:${server.address}';
                      final latency =
                          testResults[serverKey]?.inMilliseconds.toString() ??
                              'N/A';
                      final provider = providers.firstWhere(
                          (provider) => provider.servers.contains(server));

                      return ListTile(
                        title: Text(
                            '${server.type.toUpperCase()}: ${server.address}'),
                        subtitle: Text(
                            '${AppLocalizations.of(context)!.latency}: $latency ms | ${provider.name}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(favorites.contains(serverKey)
                                  ? Icons.star
                                  : Icons.star_border),
                              onPressed: () => toggleFavorite(serverKey),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh),
                              onPressed: () => startTest(server),
                            ),
                            IconButton(
                              icon: Icon(Icons.content_copy),
                              onPressed: () => copyToClipboard(server.address),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButton: FutureBuilder<List<DnsProvider>>(
        future: dnsProviders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return FloatingActionButton(
              onPressed: null,
              child: Icon(Icons.error),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return FloatingActionButton(
              onPressed: null,
              child: Icon(Icons.error),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: FloatingActionButton.extended(
                onPressed: () => testAllServers(dnsProviders),
                label: Text(AppLocalizations.of(context)!.testAllServers),
                icon: Icon(Icons.play_arrow),
                backgroundColor: Theme.of(context).primaryColor,
              ),
            );
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.grey[800] : Colors.purple[200],
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}
