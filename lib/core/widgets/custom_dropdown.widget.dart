import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.itemAsString,
    required this.onChanged,
    super.key,
    this.items,
    this.asyncItems,
    this.selectedItem,
    this.readOnly = false,
    this.suffixIcon,
    this.compareFn,
    this.filterFn,
    this.showSearchBox = true,
  });

  final String label;
  final List<T>? items; // Make items optional
  final Future<List<T>> Function(String filter, LoadProps? loadProps)? asyncItems; // Add async items
  final T? selectedItem;
  final void Function(T?) onChanged;

  /// Required to display item text
  final String Function(T) itemAsString;

  /// Optional compare logic
  final bool Function(T, T)? compareFn;

  /// Optional custom search logic
  final bool Function(T item, String filter)? filterFn;

  final bool readOnly;
  final IconData? suffixIcon;
  final bool showSearchBox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Label
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.grey700,
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),

        /// Dropdown
        DropdownSearch<T>(
          selectedItem: selectedItem,
          enabled: !readOnly,

          /// Selected item builder
          dropdownBuilder: (context, selectedItem) {
            if (selectedItem == null) return const SizedBox();

            return Text(
              itemAsString(selectedItem),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            );
          },

          /// Display string
          itemAsString: itemAsString,

          /// Compare function (fallback to equality)
          compareFn: compareFn ?? (item1, item2) => item1 == item2,

          /// Decoration
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          /// Suffix icon
          suffixProps: DropdownSuffixProps(
            dropdownButtonProps: DropdownButtonProps(
              iconOpened: suffixIcon != null
                  ? Icon(suffixIcon, color: AppTheme.grey400)
                  : const Icon(Icons.arrow_drop_up, color: AppTheme.grey400),
              iconClosed: suffixIcon != null
                  ? Icon(suffixIcon, color: AppTheme.grey400)
                  : const Icon(Icons.arrow_drop_down, color: AppTheme.grey400),
            ),
          ),

          /// Popup
          popupProps: PopupProps.menu(
            showSearchBox: showSearchBox,
            searchFieldProps: const TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            itemBuilder:
                (
                  BuildContext context,
                  T item,
                  bool isSelected,
                  bool? isDisabled,
                ) {
                  return ListTile(
                    title: Text(itemAsString(item)),
                    enabled: !(isDisabled ?? false),
                  );
                },
          ),

          /// Async items with search support
          items: (String filter, LoadProps? loadProps) async {
            if (asyncItems != null) {
              return await asyncItems!(filter, loadProps);
            }
            if (items == null) return [];
            
            if (filter.isEmpty) return items!;

            if (filterFn != null) {
              return items!.where((item) => filterFn!(item, filter)).toList();
            }

            return items!
                .where(
                  (item) => itemAsString(
                    item,
                  ).toLowerCase().contains(filter.toLowerCase()),
                )
                .toList();
          },

          onSelected: onChanged,
        ),
      ],
    );
  }
}







