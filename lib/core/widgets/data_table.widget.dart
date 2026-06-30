import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class DataTableWidget extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final bool showRowNumbers;
  final String? emptyMessage;
  final IconData? emptyIcon;

  /// Width of each column
  final double columnWidth;

  const DataTableWidget({
    super.key,
    required this.headers,
    required this.rows,
    this.showRowNumbers = false,
    this.emptyMessage,
    this.emptyIcon,
    this.columnWidth = 130, // default column width
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      child: rows.isEmpty && emptyMessage != null
          ? _buildEmptyState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.spacing6),
                ...rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return _buildRow(index + 1, row);
                }),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final effectiveHeaders = showRowNumbers ? ['#', ...headers] : headers;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: effectiveHeaders.map((header) {
        return _buildCell(
          child: Text(
            header.toUpperCase(),
            style: const TextStyle(
              fontSize: AppTheme.fontSize11,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRow(int rowNumber, List<Widget> rowData) {
    final effectiveData = showRowNumbers
        ? [_buildRowNumber(rowNumber), ...rowData]
        : rowData;

    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacing6),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: effectiveData.map((cell) {
          return _buildCell(child: cell);
        }).toList(),
      ),
    );
  }

  Widget _buildCell({required Widget child}) {
    return Container(
      width: columnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _buildRowNumber(int number) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radius8)),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: const TextStyle(
            fontSize: AppTheme.fontSize12,
            fontWeight: FontWeight.w700,
            color: AppTheme.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon ?? Icons.inbox_outlined,
              size: 64,
              color: AppTheme.grey400.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              emptyMessage ?? 'No data available',
              style: const TextStyle(
                fontSize: AppTheme.fontSize15,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}







