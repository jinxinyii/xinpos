import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';

import '../../domain/entities/business_expense.dart';
import '../../data/repositories/expense_repository.dart';
import '../providers/expense_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _period = 'This month';
  DateTimeRange? _customRange;

  static const _categories = [
    'Supplies',
    'Utilities',
    'Rent',
    'Transportation',
    'Food',
    'Salary',
    'Maintenance',
    'Marketing',
    'Other',
  ];

  static const _paymentMethods = [
    'Cash',
    'GCash',
    'BDO',
    'GoTyme',
    'Bank Transfer',
    'Other',
  ];

  String _money(int centavos) => NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  ).format(centavos / 100);

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  List<BusinessExpense> _filtered(List<BusinessExpense> expenses) {
    final now = DateTime.now();
    final today = _day(now);
    late DateTime start;
    late DateTime end;

    switch (_period) {
      case 'Today':
        start = today;
        end = today.add(const Duration(days: 1));
        break;
      case 'This week':
        start = today.subtract(Duration(days: today.weekday - 1));
        end = today.add(const Duration(days: 1));
        break;
      case 'This month':
        start = DateTime(today.year, today.month);
        end = today.add(const Duration(days: 1));
        break;
      case 'Custom':
        start = _customRange?.start ?? today;
        end = (_customRange?.end ?? today).add(const Duration(days: 1));
        break;
      default:
        start = DateTime(2000);
        end = today.add(const Duration(days: 1));
    }

    return expenses.where((expense) {
      final date = _day(expense.expenseDate);
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: _day(now),
          ),
    );

    if (!mounted || range == null) return;
    setState(() {
      _period = 'Custom';
      _customRange = range;
    });
  }

  Future<void> _showExpenseForm({BusinessExpense? expense}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ExpenseFormDialog(
        expense: expense,
        categories: _categories,
        paymentMethods: _paymentMethods,
        repository: ref.read(expenseRepositoryProvider),
      ),
    );

    if (saved == true) {
      ref.invalidate(expensesProvider);
      _showNotice(expense == null ? 'Expense added' : 'Expense updated');
    }
  }

  Future<void> _deleteExpense(BusinessExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Delete "${expense.description}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
    ref.invalidate(expensesProvider);
    _showNotice('Expense deleted');
  }

  void _showNotice(String message) {
    AppNotification.show(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Profit & Loss',
            onPressed: () => context.go('/profit'),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(expensesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Unable to load expenses.'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.invalidate(expensesProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (allExpenses) {
          final expenses = _filtered(allExpenses);
          final total = expenses.fold<int>(
            0,
            (sum, expense) => sum + expense.amountCentavos,
          );
          final wide = MediaQuery.sizeOf(context).width >= 800;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(expensesProvider),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                16,
                wide ? 28 : 16,
                100,
              ),
              children: [
                Card(
                  elevation: 0,
                  color: colors.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: TextStyle(color: colors.onPrimaryContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _money(total),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expenses.length} records',
                          style: TextStyle(color: colors.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final period in [
                      'Today',
                      'This week',
                      'This month',
                      'All',
                    ])
                      ChoiceChip(
                        label: Text(period),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                      ),
                    OutlinedButton.icon(
                      onPressed: _selectCustomRange,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        _period == 'Custom' ? 'Custom range' : 'Date range',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Expense History',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${expenses.length} entries',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    child: const Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 38),
                          SizedBox(height: 10),
                          Text('No expenses for this period'),
                          SizedBox(height: 4),
                          Text('Add an expense to start tracking your costs.'),
                        ],
                      ),
                    ),
                  )
                else
                  ...expenses.map(
                    (expense) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: colors.surfaceContainerLow,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors.secondaryContainer,
                          foregroundColor: colors.onSecondaryContainer,
                          child: const Icon(Icons.payments_outlined),
                        ),
                        title: Text(
                          expense.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${expense.category} · ${DateFormat('MMM d, yyyy').format(expense.expenseDate)}'
                          '${expense.paymentMethod == null ? '' : ' · ${expense.paymentMethod}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _money(expense.amountCentavos),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showExpenseForm(expense: expense);
                                } else if (value == 'delete') {
                                  _deleteExpense(expense);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  final BusinessExpense? expense;
  final List<String> categories;
  final List<String> paymentMethods;
  final ExpenseRepository repository;

  const _ExpenseFormDialog({
    required this.expense,
    required this.categories,
    required this.paymentMethods,
    required this.repository,
  });

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late String _category;
  late String? _paymentMethod;
  late DateTime _expenseDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _amountController = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amountCentavos / 100).toStringAsFixed(2),
    );
    _category = expense?.category ?? widget.categories.first;
    _paymentMethod = expense?.paymentMethod;
    _expenseDate = expense?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _expenseDate = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    final amountCentavos = (amount * 100).round();

    setState(() => _saving = true);
    try {
      await widget.repository.saveExpense(
        id: widget.expense?.id,
        description: _descriptionController.text,
        category: _category,
        amountCentavos: amountCentavos,
        paymentMethod: _paymentMethod,
        expenseDate: _expenseDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Unable to save expense: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'e.g. Store electricity bill',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    if (amount > 999999999) return 'Amount is too large';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not specified'),
                    ),
                    ...widget.paymentMethods.map(
                      (method) => DropdownMenuItem<String?>(
                        value: method,
                        child: Text(method),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _paymentMethod = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('MMMM d, yyyy').format(_expenseDate)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Expense'),
        ),
      ],
    );
  }
}
