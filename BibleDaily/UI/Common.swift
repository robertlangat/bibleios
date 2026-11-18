import SwiftUI
import UIKit

enum Highlight {
    static let colors: [Color] = [
        Color(red: 1.00, green: 0.88, blue: 0.51), // yellow
        Color(red: 0.65, green: 0.84, blue: 0.65), // green
        Color(red: 0.56, green: 0.79, blue: 0.98), // blue
        Color(red: 0.96, green: 0.56, blue: 0.69), // pink
    ]
    static let names = ["yellow", "green", "blue", "pink"]

    static func color(_ index: Int, dark: Bool) -> Color? {
        guard (1...colors.count).contains(index) else { return nil }
        return colors[index - 1].opacity(dark ? 0.32 : 0.65)
    }
}

func copyToClipboard(_ text: String) {
    UIPasteboard.general.string = text
}

/// Outlined card used on Home and Search (white with a thin black border in light mode).
struct OutlinedCard<Content: View>: View {
    var strong = false
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(strong ? Color.primary : Color.secondary.opacity(0.4), lineWidth: 1))
    }
}

/// Bottom sheet with bookmark, note, copy, share and highlight actions for one verse.
struct VerseActionsSheet: View {
    let verse: Verse
    let reference: String
    let shareText: String
    @EnvironmentObject private var marks: MarksStore
    @Environment(\.dismiss) private var dismiss
    var onNote: () -> Void

    private var key: VerseKey { VerseKey(book: verse.book, chapter: verse.chapter, verse: verse.verse) }

    var body: some View {
        let mark = marks.mark(key)
        VStack(alignment: .leading, spacing: 14) {
            Text(reference).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            Text(verse.text).font(.subheadline).lineLimit(3)
            HStack {
                action(mark?.bookmarked == true ? "bookmark.fill" : "bookmark",
                       mark?.bookmarked == true ? "Bookmarked" : "Bookmark",
                       mark?.bookmarked == true ? "Remove bookmark" : "Bookmark verse", "action_bookmark") {
                    marks.update(key) { $0.bookmarked.toggle() }
                }
                action("square.and.pencil", mark?.hasNote == true ? "Edit note" : "Note",
                       mark?.hasNote == true ? "Edit note" : "Add note", "action_note") { onNote() }
                action("doc.on.doc", "Copy", "Copy verse", "action_copy") {
                    copyToClipboard(shareText)
                    dismiss()
                }
                ShareLink(item: shareText, subject: Text(reference)) {
                    actionLabel("square.and.arrow.up", "Share")
                }
                .accessibilityLabel("Share verse")
                .accessibilityIdentifier("action_share")
                .frame(maxWidth: .infinity)
            }
            Text("Highlight").font(.subheadline.weight(.semibold))
            HStack(spacing: 14) {
                ForEach(1...Highlight.colors.count, id: \.self) { i in
                    let selected = mark?.highlight == i
                    Button {
                        marks.update(key) { $0.highlight = selected ? 0 : i }
                    } label: {
                        Circle().fill(Highlight.colors[i - 1])
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(selected ? Color.primary : Color.secondary.opacity(0.5), lineWidth: selected ? 3 : 1))
                            .overlay(selected ? Image(systemName: "checkmark").foregroundStyle(.black) : nil)
                    }
                    .accessibilityLabel("Highlight \(Highlight.names[i - 1])")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("highlight_\(i)")
                }
                if (mark?.highlight ?? 0) != 0 {
                    Button { marks.update(key) { $0.highlight = 0 } } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.5)))
                    }
                    .accessibilityLabel("Remove highlight")
                    .accessibilityIdentifier("highlight_0")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func action(_ icon: String, _ label: String, _ description: String, _ id: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { actionLabel(icon, label) }
            .accessibilityLabel(description)
            .accessibilityIdentifier(id)
            .frame(maxWidth: .infinity)
    }

    private func actionLabel(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(label).font(.caption)
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 60, minHeight: 50)
    }
}

struct NoteEditor: View {
    let reference: String
    let initial: String
    var onSave: (String?) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Write your note", text: $text, axis: .vertical)
                    .lineLimit(5...14)
                    .focused($focused)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4)))
                    .accessibilityLabel("Your note")
                    .accessibilityIdentifier("note_field")
                Spacer()
            }
            .padding()
                .navigationTitle("Note · \(reference)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave(text); dismiss() }.accessibilityIdentifier("note_save")
                    }
                    if !initial.isEmpty {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Delete note", role: .destructive) { onSave(nil); dismiss() }
                                .accessibilityIdentifier("note_delete")
                        }
                    }
                }
                .onAppear {
                    text = initial
                    focused = true
                }
        }
    }
}
