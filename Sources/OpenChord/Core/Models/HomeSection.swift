import Foundation

enum HomeSectionLayout: Codable, Hashable, Sendable {
    case carousel(rows: Int)
    case grid(columns: Int)
    case list

    private enum CodingKeys: String, CodingKey {
        case kind
        case count
    }

    private enum Kind: String, Codable {
        case carousel
        case grid
        case list
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .carousel:
            self = .carousel(rows: max(1, try container.decode(Int.self, forKey: .count)))
        case .grid:
            self = .grid(columns: max(1, try container.decode(Int.self, forKey: .count)))
        case .list:
            self = .list
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .carousel(let rows):
            try container.encode(Kind.carousel, forKey: .kind)
            try container.encode(max(1, rows), forKey: .count)
        case .grid(let columns):
            try container.encode(Kind.grid, forKey: .kind)
            try container.encode(max(1, columns), forKey: .count)
        case .list:
            try container.encode(Kind.list, forKey: .kind)
        }
    }
}

enum HomeArtworkShape: String, CaseIterable, Codable, Hashable, Sendable {
    case square
    case rounded
    case circle
}

struct HomeSection: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var kindID: String
    var title: String
    var isEnabled: Bool
    var order: Int
    var layout: HomeSectionLayout
    var itemLimit: Int
    var artworkShape: HomeArtworkShape

    init(
        id: UUID = UUID(),
        kindID: String,
        title: String,
        isEnabled: Bool = true,
        order: Int,
        layout: HomeSectionLayout = .carousel(rows: 1),
        itemLimit: Int = 20,
        artworkShape: HomeArtworkShape = .rounded
    ) {
        self.id = id
        self.kindID = kindID
        self.title = title
        self.isEnabled = isEnabled
        self.order = order
        self.layout = layout
        self.itemLimit = max(1, itemLimit)
        self.artworkShape = artworkShape
    }

    static let v2Defaults: [HomeSection] = [
        HomeSection(kindID: "recentlyPlayed", title: "Recently Played", order: 0),
        HomeSection(kindID: "recentlyAdded", title: "Recently Added", order: 1),
        HomeSection(kindID: "playlists", title: "Playlists", order: 2),
        HomeSection(kindID: "albums", title: "Albums", order: 3),
        HomeSection(kindID: "newReleases", title: "New Releases", order: 4)
    ]
}
