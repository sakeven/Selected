import SwiftUI

public class ResponseMessage: ObservableObject, Identifiable, Equatable{
    public static func == (lhs: ResponseMessage, rhs: ResponseMessage) -> Bool {
        lhs.id == rhs.id
    }

    public enum Status: String {
        case initial, updating, finished, failure
    }

    public enum Role: String {
        case assistant, user, system
    }

    public var id = UUID()

    @Published var summary: String
    @Published var message: String
    @Published var images: [Data]
    let previewImages: [NSImage?]
    let files: [AIFileAttachment]

    @Published var role: Role
    @Published var status: Status
    @Published var tools: [String: AIToolCall] {
        didSet {
            items = tools.sorted { $0.key < $1.key }
        }
    }

    var items: [(key: String, value: AIToolCall)]

    var new: Bool = false // new start of message

    init(id: UUID = UUID(), message: String, images: [Data] = [], files: [AIFileAttachment] = [], role: Role, new: Bool = false, status: Status = .initial) {
        self.id = id
        self.message = message
        self.role = role
        self.new = new
        self.status = status
        self.summary = ""
        self.images = images
        self.previewImages = images.map(NSImage.init(data:))
        self.files = files
        self.tools = [String: AIToolCall]()
        self.items = []
    }

    func applyContentEvent(_ event: AIStreamEvent) {
        switch event {
            case .textDelta(let txt):
                message += txt
            case .textDone(let txt):
                message = txt
                status = .finished
            case .toolCallStarted(let toolStartStatus):
                tools[toolStartStatus.id] = AIToolCall(
                    name: toolStartStatus.name,
                    ret: toolStartStatus.message,
                    status: .calling,
                    arguments: toolStartStatus.arguments,
                    command: toolStartStatus.command,
                    workdir: toolStartStatus.workdir,
                    sourceLinks: toolStartStatus.sourceLinks
                )
            case .toolCallFinished(let result):
                let currentTool = tools[result.id]
                tools[result.id] = AIToolCall(
                    name: result.name,
                    ret: result.ret,
                    status: .success,
                    arguments: result.arguments ?? currentTool?.arguments,
                    command: result.command ?? currentTool?.command,
                    workdir: result.workdir ?? currentTool?.workdir,
                    sourceLinks: Self.mergedSourceLinks(currentTool?.sourceLinks ?? [], result.sourceLinks)
                )
            case .toolCallUpdated(let update):
                if let currentTool = tools[update.id] {
                    tools[update.id] = AIToolCall(
                        name: currentTool.name,
                        ret: currentTool.ret,
                        status: currentTool.status,
                        arguments: currentTool.arguments,
                        command: currentTool.command,
                        workdir: currentTool.workdir,
                        sourceLinks: Self.mergedSourceLinks(currentTool.sourceLinks, update.sourceLinks)
                    )
                }
            case .reasoningDelta(let reasoningDelta):
                summary += reasoningDelta
            case .reasoningDone(_):
                // only part of reasoning context done.
                summary +=  "\n\n"
            default:
                break
        }
    }

    private static func mergedSourceLinks(_ current: [AIToolSourceLink], _ incoming: [AIToolSourceLink]) -> [AIToolSourceLink] {
        var seen = Set<String>()
        return (current + incoming).filter { link in
            seen.insert(link.id).inserted
        }
    }
}
