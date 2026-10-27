import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 18

    static func statusColor(_ status: JobStatus) -> Color {
        switch status {
        case .planned: .blue
        case .inProgress: .orange
        case .completed: .green
        }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.indigo.opacity(0.22), Color.mint.opacity(0.08), Color.clear]
                : [Color.blue.opacity(0.12), Color.mint.opacity(0.10), Color.white.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct FeatureIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}

struct StatusBadge: View {
    let status: JobStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.statusColor(status))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.statusColor(status).opacity(0.13), in: Capsule())
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(Color.primary.opacity(0.06))
            }
            .shadow(color: Color.black.opacity(0.06), radius: 9, y: 4)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appListAppearance() -> some View {
        scrollContentBackground(.hidden)
            .background(AppBackground())
    }
}
