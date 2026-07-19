import AppKit
import SwiftUI

struct SkillsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var selectedSkill: GrokSkill?

    private var filtered: [GrokSkill] {
        guard !query.isEmpty else { return model.skills }
        return model.skills.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
                || $0.description.localizedCaseInsensitiveContains(query)
                || $0.scope.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扩展 Grok Build 的任务能力").font(GrokTypography.item(.semibold))
                    Text("显示 Grok 当前工作目录、用户目录、服务端与插件提供的 Skills。")
                        .font(GrokTypography.metadata).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.refreshSkills() } label: { Label("刷新", systemImage: "arrow.clockwise") }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索 Skills", text: $query).textFieldStyle(.plain)
                Text("\(filtered.count)").font(GrokTypography.metadata).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 11).frame(height: 34)
            .background(.background, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.primary.opacity(0.10)))

            if filtered.isEmpty {
                ContentUnavailableView(query.isEmpty ? "未发现 Skills" : "没有匹配的 Skill",
                                       systemImage: "shippingbox",
                                       description: Text(query.isEmpty ? "请确认 ~/.grok/skills 或项目 .grok/skills 中存在 SKILL.md。" : "尝试其他关键词。"))
                    .frame(maxWidth: .infinity).padding(.vertical, 56)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], spacing: 8) {
                    ForEach(filtered) { skill in
                        SkillRow(skill: skill) { selectedSkill = skill }
                    }
                }
            }
        }
        .onAppear { model.refreshSkills() }
        .sheet(item: $selectedSkill) { skill in
            SkillDetailView(skillID: skill.id)
        }
    }
}

private struct SkillRow: View {
    let skill: GrokSkill
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(.secondary.opacity(0.08))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "shippingbox.fill").foregroundStyle(skill.enabled ? .primary : .tertiary))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(skill.title).font(GrokTypography.item(.medium)).lineLimit(1)
                        Text(skill.scope.capitalized).font(GrokTypography.metadata).foregroundStyle(.tertiary)
                    }
                    Text(skill.shortDescription ?? skill.description)
                        .font(GrokTypography.metadata).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: skill.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skill.enabled ? Color.green : Color.secondary)
            }
            .padding(.horizontal, 10).frame(height: 58).contentShape(Rectangle())
            .background(.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct SkillDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let skillID: String

    private var skill: GrokSkill? { model.skills.first { $0.id == skillID } }

    var body: some View {
        if let skill {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 11).fill(.secondary.opacity(0.09)).frame(width: 46, height: 46)
                        .overlay(Image(systemName: "shippingbox.fill").font(.title3))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skill.title).font(.title2.weight(.semibold))
                        Text(skill.invocation).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { skill.enabled }, set: { model.toggleSkill(skill, enabled: $0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    Menu {
                        Button("在 Finder 中显示") { reveal(skill) }
                        Button("打开 SKILL.md") { NSWorkspace.shared.open(URL(fileURLWithPath: skill.path)) }
                        Divider()
                        Button("复制斜杠命令") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(skill.invocation, forType: .string)
                        }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                    Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }

                Text(skill.description).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SkillBadge(text: skill.scope.capitalized)
                    if let author = skill.author { SkillBadge(text: author) }
                    if !skill.userInvocable { SkillBadge(text: "仅模型调用") }
                    if let compatibility = skill.compatibility { SkillBadge(text: compatibility) }
                }
                if let whenToUse = skill.whenToUse, !whenToUse.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("何时使用").font(GrokTypography.metadata(.semibold)).foregroundStyle(.secondary)
                        Text(whenToUse).font(GrokTypography.metadata)
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text("SKILL.md").font(GrokTypography.metadata(.semibold)); Spacer(); Text(skill.path).font(GrokTypography.metadata).foregroundStyle(.tertiary).lineLimit(1) }
                    ScrollView { MarkdownText(text: skill.content).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                        .background(.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.07)))
                }
                HStack {
                    Button("在 Finder 中显示") { reveal(skill) }
                    Spacer()
                    Button("复制 \(skill.invocation)") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(skill.invocation + " ", forType: .string)
                    }.buttonStyle(.borderedProminent)
                }
            }
            .padding(22).frame(width: 680, height: 620)
        } else {
            ContentUnavailableView("Skill 已刷新或移除", systemImage: "shippingbox")
                .frame(width: 500, height: 300)
        }
    }

    private func reveal(_ skill: GrokSkill) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: skill.path)])
    }
}

private struct SkillBadge: View {
    let text: String
    var body: some View {
        Text(text).font(GrokTypography.metadata).padding(.horizontal, 8).padding(.vertical, 4)
            .background(.secondary.opacity(0.08), in: Capsule())
    }
}
