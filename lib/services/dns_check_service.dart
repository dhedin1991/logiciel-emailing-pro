import 'dart:convert';
import 'package:http/http.dart' as http;

class DnsCheckResult {
  final String domain;
  final bool isFreeProvider;
  final bool? spf;
  final bool? dmarc;
  final bool? dkim;
  final String? dkimSelector;
  final String? error;

  const DnsCheckResult({
    required this.domain,
    required this.isFreeProvider,
    this.spf,
    this.dmarc,
    this.dkim,
    this.dkimSelector,
    this.error,
  });
}

/// Vérifie la configuration SPF / DKIM / DMARC d'un domaine d'expédition,
/// via le service DNS public de Google (DNS sur HTTPS).
class DnsCheckService {
  static const freeProviders = {
    'gmail.com', 'googlemail.com', 'outlook.com', 'outlook.fr', 'hotmail.com', 'hotmail.fr',
    'live.com', 'live.fr', 'msn.com', 'yahoo.com', 'yahoo.fr', 'icloud.com', 'me.com',
    'gmx.com', 'gmx.fr', 'gmx.net', 'protonmail.com', 'proton.me', 'aol.com', 'orange.fr',
    'free.fr', 'laposte.net', 'sfr.fr', 'wanadoo.fr',
  };

  static const _dkimSelectors = [
    'default', 'google', 'selector1', 'selector2', 'k1', 'k2', 'mail', 's1', 's2', 'dkim',
  ];

  Future<List<String>> _txt(String name) async {
    final uri = Uri.https('dns.google', '/resolve', {'name': name, 'type': 'TXT'});
    final resp = await http.get(uri, headers: {'Accept': 'application/dns-json'}).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Service DNS indisponible (${resp.statusCode})');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final answers = (data['Answer'] as List<dynamic>?) ?? const [];
    return answers
        .map((a) => ((a as Map<String, dynamic>)['data'] as String? ?? '').replaceAll('"', ''))
        .toList();
  }

  Future<DnsCheckResult> check(String email) async {
    final domain = email.contains('@') ? email.split('@').last.toLowerCase().trim() : email.toLowerCase();
    if (freeProviders.contains(domain)) {
      return DnsCheckResult(domain: domain, isFreeProvider: true);
    }
    try {
      final root = await _txt(domain);
      final spf = root.any((r) => r.toLowerCase().startsWith('v=spf1'));
      final dmarcRecords = await _txt('_dmarc.$domain');
      final dmarc = dmarcRecords.any((r) => r.toUpperCase().startsWith('V=DMARC1'));
      bool dkim = false;
      String? foundSelector;
      for (final sel in _dkimSelectors) {
        final records = await _txt('$sel._domainkey.$domain');
        if (records.any((r) => r.toUpperCase().contains('V=DKIM1') || r.contains('p='))) {
          dkim = true;
          foundSelector = sel;
          break;
        }
      }
      return DnsCheckResult(
        domain: domain,
        isFreeProvider: false,
        spf: spf,
        dmarc: dmarc,
        dkim: dkim,
        dkimSelector: foundSelector,
      );
    } catch (e) {
      return DnsCheckResult(domain: domain, isFreeProvider: false, error: e.toString());
    }
  }
}
