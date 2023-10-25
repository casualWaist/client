import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BarChartCard extends StatelessWidget {
  const BarChartCard({
    Key? key,
    required this.barChartTitle,
    required this.barChart,
    required this.legend,
    required this.loadingData,
  }) : super(key: key);

  final String barChartTitle;
  final BarChart? barChart;
  final Widget legend;
  final bool loadingData;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            Text(
              barChartTitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 2,
              child: loadingData
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : barChart,
            ),
            const SizedBox(height: 10),
            legend,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}