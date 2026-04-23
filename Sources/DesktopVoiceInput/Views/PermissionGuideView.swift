import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    let compact: Bool

    private let primaryText = Color(red: 0.10, green: 0.14, blue: 0.20)
    private let secondaryText = Color(red: 0.36, green: 0.41, blue: 0.49)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: appModel.hasMissingPermissions ? "hand.raised.fill" : "checkmark.shield.fill")
                    .font(.system(size: compact ? 18 : 22, weight: .semibold))
                    .foregroundStyle(appModel.hasMissingPermissions ? .orange : .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.hasMissingPermissions ? "还差几项权限才能正常工作" : "权限已经准备好了")
                        .font(.system(size: compact ? 14 : 18, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text(appModel.hasMissingPermissions
                         ? "建议按顺序把下面几项补齐。只有缺失时才会去申请或引导跳转。"
                         : "现在可以尝试按住快捷键说话，看看能不能顺利出字。")
                        .font(.system(size: compact ? 12 : 13))
                        .foregroundStyle(secondaryText)
                }
            }

            if appModel.hasMissingPermissions {
                ForEach(AppPermissionKind.allCases) { permission in
                    permissionRow(permission)
                }
            }
        }
        .padding(compact ? 14 : 18)
        .background(
            appModel.hasMissingPermissions ? Color.orange.opacity(0.08) : Color.green.opacity(0.08),
            in: RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .stroke(appModel.hasMissingPermissions ? Color.orange.opacity(0.25) : Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    private func permissionRow(_ permission: AppPermissionKind) -> some View {
        let state = appModel.permissionCoordinator.state(for: permission)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(permission.title)
                        .font(.system(size: compact ? 13 : 14, weight: .medium))
                        .foregroundStyle(primaryText)
                    Text(state.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(state.isUsable ? Color.green.opacity(0.14) : Color.orange.opacity(0.14), in: Capsule())
                }

                Text(permission.guidance)
                    .font(.system(size: compact ? 11 : 12))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if !state.isUsable {
                Button(appModel.actionLabel(for: permission)) {
                    appModel.handlePermissionAction(permission)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .small : .regular)
            }
        }
        .padding(.vertical, compact ? 2 : 4)
    }
}
