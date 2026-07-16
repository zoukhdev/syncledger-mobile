import 'dart:io';
import 'dart:convert';

void main() async {
  final keys = {
    "searchLogs": "Search logs...",
    "details": "Details",
    "phases": "Phases",
    "contractDocument": "Contract Document",
    "uploadDocument": "Upload Document",
    "viewFullDocument": "View Full Document",
    "budget": "Budget",
    "paidOut": "Paid Out",
    "remaining": "Remaining",
    "mfaSetup": "MFA Setup",
    "auditLogs": "Audit Logs",
    "search": "Search"
  };

  final frVals = {
    "searchLogs": "Rechercher des journaux...",
    "details": "Détails",
    "phases": "Phases",
    "contractDocument": "Document de contrat",
    "uploadDocument": "Télécharger un document",
    "viewFullDocument": "Voir le document complet",
    "budget": "Budget",
    "paidOut": "Payé",
    "remaining": "Restant",
    "mfaSetup": "Configuration MFA",
    "auditLogs": "Journaux d'audit",
    "search": "Recherche"
  };

  final arVals = {
    "searchLogs": "بحث في السجلات...",
    "details": "تفاصيل",
    "phases": "مراحل",
    "contractDocument": "مستند العقد",
    "uploadDocument": "تحميل مستند",
    "viewFullDocument": "عرض المستند الكامل",
    "budget": "الميزانية",
    "paidOut": "المدفوع",
    "remaining": "المتبقي",
    "mfaSetup": "إعداد المصادقة الثنائية",
    "auditLogs": "سجلات التدقيق",
    "search": "بحث"
  };

  void updateArb(String path, Map<String, String> extraKeys) {
    final file = File(path);
    if (!file.existsSync()) return;
    String content = file.readAsStringSync();
    
    // Simple way to inject keys before the last '}'
    final pos = content.lastIndexOf('}');
    if (pos == -1) return;
    
    String toAdd = '';
    for (var entry in extraKeys.entries) {
      if (!content.contains('"${entry.key}"')) {
        toAdd += ',\n  "${entry.key}": "${entry.value}"';
      }
    }
    
    if (toAdd.isNotEmpty) {
      content = content.substring(0, pos) + toAdd + '\n' + content.substring(pos);
      file.writeAsStringSync(content);
      print('Updated $path');
    }
  }

  updateArb('lib/l10n/app_en.arb', keys);
  updateArb('lib/l10n/app_fr.arb', frVals);
  updateArb('lib/l10n/app_ar.arb', arVals);
}
