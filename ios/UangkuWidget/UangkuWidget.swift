import WidgetKit
import SwiftUI
import AppIntents
// Struktur Data yang diambil dari App Group (UserDefaults)
struct WidgetData {
    let balanceText: String
    let incomeText: String
    let expenseText: String
    let netText: String
    let isHidden: Bool
    let isNetNegative: Bool
    let lastUpdated: String
    
    // URI untuk Deep Linking
    let rootUri = URL(string: "uangku://dashboard")!
    let toggleUri = URL(string: "uangku://toggle-balance-visibility")!
    let incomeUri = URL(string: "uangku://open-income-input")!
    let expenseUri = URL(string: "uangku://open-expense-input")!
    
    init(userDefaults: UserDefaults) {
        isHidden = userDefaults.bool(forKey: "widget_balance_hidden")
        isNetNegative = userDefaults.bool(forKey: "widget_net_negative")
        lastUpdated = userDefaults.string(forKey: "widget_last_updated") ?? "Belum diperbarui"
        
        let rawBalance = userDefaults.string(forKey: "widget_balance_text") ?? "Rp 0"
        let rawIncome = userDefaults.string(forKey: "widget_total_income_text") ?? "Rp 0"
        let rawExpense = userDefaults.string(forKey: "widget_total_expense_text") ?? "Rp 0"
        let rawNet = userDefaults.string(forKey: "widget_net_text") ?? rawBalance
        
        let masked = "Rp ••••••"
        balanceText = isHidden ? masked : rawBalance
        incomeText = isHidden ? masked : rawIncome
        expenseText = isHidden ? masked : rawExpense
        netText = isHidden ? masked : rawNet
    }
}
// Data Entry untuk timeline widget
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UangkuEntry {
        UangkuEntry(date: Date(), data: getWidgetData())
    }
    func getSnapshot(in context: Context, completion: @escaping (UangkuEntry) -> ()) {
        let entry = UangkuEntry(date: Date(), data: getWidgetData())
        completion(entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = UangkuEntry(date: Date(), data: getWidgetData())
        // Widget akan di-refresh dari Flutter, tapi kita set refresh otomatis setiap 1 jam sebagai fallback
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getWidgetData() -> WidgetData {
        // MENGGUNAKAN APP GROUP ID SESUAI DENGAN FLUTTER
        let sharedDefaults = UserDefaults(suiteName: "group.com.example.uangkeluar")
            ?? UserDefaults.standard
        return WidgetData(userDefaults: sharedDefaults)
    }
}
struct UangkuEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}
// Tampilan (UI) dari Widget
struct UangkuWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        let isDark = colorScheme == .dark
        let labelColor = isDark ? Color.white : Color(red: 45/255, green: 45/255, blue: 45/255)
        let valueColor = isDark ? Color.white : Color(red: 17/255, green: 17/255, blue: 17/255)
        let expenseColor = Color(red: 194/255, green: 69/255, blue: 69/255) // #C24545
        let expenseLabelColor = isDark ? Color(red: 255/255, green: 157/255, blue: 142/255) : Color(red: 45/255, green: 45/255, blue: 45/255)
        let mutedColor = isDark ? Color.white.opacity(0.5) : Color(red: 45/255, green: 45/255, blue: 45/255).opacity(0.5)
        
        let netColor = entry.data.isHidden ? valueColor : (entry.data.isNetNegative ? expenseColor : valueColor)
        VStack(alignment: .leading, spacing: 12) {
            // Header: "Sisa Saldo" & Tombol Toggle
            HStack {
                Text("Sisa Saldo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(labelColor)
                
                Spacer()
                
                // Link/Button untuk toggle visibility
                if #available(iOS 17.0, *) {
                    Button(intent: ToggleVisibilityIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: entry.data.isHidden ? "eye" : "eye.slash")
                            Text(entry.data.isHidden ? "Show" : "Hide")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(valueColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isDark ? Color.black : Color(red: 240/255, green: 240/255, blue: 240/255))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: entry.data.toggleUri) {
                        HStack(spacing: 4) {
                            Image(systemName: entry.data.isHidden ? "eye" : "eye.slash")
                            Text(entry.data.isHidden ? "Show" : "Hide")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(valueColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isDark ? Color.black : Color(red: 240/255, green: 240/255, blue: 240/255))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Sisa Saldo Value
            Text(entry.data.balanceText)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(netColor)
            
            // Pemasukan & Pengeluaran Row
            HStack(spacing: 8) {
                // Tombol Pemasukan
                Link(destination: entry.data.incomeUri) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(isDark ? .white : .black)
                            Text("Pemasukan")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(labelColor)
                        }
                        Text(entry.data.incomeText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(valueColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(isDark ? Color.black : Color.white)
                    .cornerRadius(8)
                }
                
                // Tombol Pengeluaran
                Link(destination: entry.data.expenseUri) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(isDark ? .white : expenseColor)
                            Text("Pengeluaran")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(expenseLabelColor)
                        }
                        Text(entry.data.expenseText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDark ? .white : expenseColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(isDark ? Color.black : Color.white)
                    .cornerRadius(8)
                }
            }
            
            // (Bagian Footer Selisih & Last Updated dihapus sesuai permintaan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        // Supaya seluruh widget bisa diklik ke Dashboard
        .widgetURL(entry.data.rootUri)
    }
}
@main
struct UangkuWidget: Widget {
    let kind: String = "UangkuWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UangkuWidgetEntryView(entry: entry)
                .background(Color("WidgetBackground")) // Gunakan default atau hapus modifier ini
        }
        .configurationDisplayName("UangKu Balance")
        .description("Pantau sisa saldo, pemasukan, dan pengeluaran Anda dengan cepat.")
        .supportedFamilies([.systemMedium]) // Widget ini didesain untuk ukuran medium
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ToggleVisibilityIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Balance Visibility"

    init() {}

    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.com.example.uangkeluar")
        let isHidden = sharedDefaults?.bool(forKey: "widget_balance_hidden") ?? false
        sharedDefaults?.set(!isHidden, forKey: "widget_balance_hidden")
        return .result()
    }
}
