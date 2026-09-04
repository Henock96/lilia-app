// Driver des tests de performance (cf. integration_test/perf_test.dart).
//
// Reçoit le reportData de chaque test, transforme les timelines en résumés
// chiffrés (FPS / jank / raster) et les écrit dans build/.
//
// Lancer :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart \
//     --profile

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Clés de timeline produites via `binding.traceAction(reportKey: ...)`.
const List<String> _timelineKeys = <String>[
  'home_scroll',
  'tab_navigation',
  'search_scroll',
  'restaurant_detail_scroll',
  'cart_scroll',
  'stress',
];

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;

      for (final key in _timelineKeys) {
        final raw = data[key];
        if (raw == null) continue;
        final timeline = driver.Timeline.fromJson(
          raw as Map<String, dynamic>,
        );
        final summary = driver.TimelineSummary.summarize(timeline);
        // Écrit build/<key>.timeline_summary.json (+ la timeline brute).
        await summary.writeTimelineToFile(
          key,
          pretty: true,
          includeSummary: true,
        );
        // Récapitulatif lisible en console.
        stdout.writeln(
          '📊 $key → '
          'avg ${summary.summaryJson['average_frame_build_time_millis']} ms/build, '
          'jank(build) ${summary.summaryJson['missed_frame_build_budget_count']}, '
          'jank(raster) ${summary.summaryJson['missed_frame_rasterizer_budget_count']}',
        );
      }

      // Métriques réseau / montée en charge custom.
      final metrics = data['perf_metrics'];
      if (metrics != null) {
        final file = File('build/perf_metrics.json');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(metrics),
        );
        stdout.writeln('📈 perf_metrics → build/perf_metrics.json : $metrics');
      }
    },
  );
}
