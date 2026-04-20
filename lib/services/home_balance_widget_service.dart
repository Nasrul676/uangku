import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class HomeBalanceWidgetService {
  HomeBalanceWidgetService._();

  static final HomeBalanceWidgetService instance = HomeBalanceWidgetService._();

  static const widgetProviderName = 'UangkuBalanceWidgetProvider';
  static const widgetExpenseLaunchUri = 'uangku://open-expense-input';
  static const widgetIncomeLaunchUri = 'uangku://open-income-input';
  static const widgetToggleVisibilityLaunchUri =
      'uangku://toggle-balance-visibility';

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> syncBalance({
    required double totalIncome,
    required double totalExpense,
    required double balance,
    required bool isHidden,
  }) async {
    final totalIncomeText = _currencyFormatter.format(totalIncome);
    final totalExpenseText = _currencyFormatter.format(totalExpense);
    final balanceText = _currencyFormatter.format(balance);
    final netText = balance > 0
        ? '+${_currencyFormatter.format(balance)}'
        : _currencyFormatter.format(balance);
    await HomeWidget.saveWidgetData<String>(
      'widget_total_income_text',
      totalIncomeText,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_total_expense_text',
      totalExpenseText,
    );
    await HomeWidget.saveWidgetData<String>('widget_balance_text', balanceText);
    await HomeWidget.saveWidgetData<String>('widget_net_text', netText);
    await HomeWidget.saveWidgetData<bool>('widget_net_negative', balance < 0);
    await HomeWidget.saveWidgetData<bool>('widget_balance_hidden', isHidden);
    await HomeWidget.saveWidgetData<String>(
      'widget_expense_launch_uri',
      widgetExpenseLaunchUri,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_income_launch_uri',
      widgetIncomeLaunchUri,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_toggle_visibility_launch_uri',
      widgetToggleVisibilityLaunchUri,
    );
    await HomeWidget.updateWidget(androidName: widgetProviderName);
  }

  Future<Uri?> getInitialLaunchUri() {
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  Stream<Uri?> get widgetClickedStream => HomeWidget.widgetClicked;

  bool isExpenseInputLaunchUri(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme == 'uangku' && uri.host == 'open-expense-input';
  }

  bool isIncomeInputLaunchUri(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme == 'uangku' && uri.host == 'open-income-input';
  }

  bool isToggleBalanceVisibilityLaunchUri(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme == 'uangku' && uri.host == 'toggle-balance-visibility';
  }
}
