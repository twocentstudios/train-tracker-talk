import CoreLocation
import Foundation
import SharingGRDB
import StructuredQueries
import Tagged

@Table struct Station: Hashable, Identifiable, Codable {
    typealias ID = Tagged<Self, String>
    public let id: ID
    let railway: Railway.ID
    @Column(as: TitleLocalization.JSONRepresentation.self)
    let title: TitleLocalization
    let order: Int
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}

@Table struct Railway: Hashable, Identifiable, Codable {
    typealias ID = Tagged<Self, String>
    let id: ID
    @Column(as: TitleLocalization.JSONRepresentation.self)
    let title: TitleLocalization
    @Column(as: [Station.ID].JSONRepresentation.self)
    let stations: [Station.ID]
    let color: String
    let ascending: RailDirection
    let descending: RailDirection
}

@Table("coordinate")
struct Coordinate: Hashable, Identifiable, Codable {
    typealias ID = Tagged<Self, Int64>
    let id: ID
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}

@Table("segment")
struct Segment: Hashable, Identifiable, Codable {
    typealias ID = Tagged<Self, Int64>
    let id: ID
    let railway: Railway.ID
    let underground: Bool
}

@Table("segmentCoordinate")
struct SegmentCoordinate: Hashable, Codable {
    let segment: Segment.ID
    let order: Int
    let coordinate: Coordinate.ID
}

struct TitleLocalization: Equatable, Hashable, Codable, Sendable {
    let en: String
    let ja: String

    func title(_ locale: Locale) -> String {
        if locale.language.languageCode == "en" {
            en
        } else {
            ja
        }
    }
}

public enum RailDirection: String, Identifiable, Equatable, Codable, CaseIterable, Comparable, Sendable, QueryBindable {
    case inbound = "Inbound"
    case outbound = "Outbound"
    case northbound = "Northbound"
    case southbound = "Southbound"
    case eastbound = "Eastbound"
    case westbound = "Westbound"
    case innerLoop = "InnerLoop"
    case outerLoop = "OuterLoop"

    // Terminal station directions
    case toeiMinowabashi = "Toei.Minowabashi"
    case toeiWaseda = "Toei.Waseda"
    case tokyoMetroAkabaneIwabushi = "TokyoMetro.AkabaneIwabuchi"
    case tokyoMetroAsakusa = "TokyoMetro.Asakusa"
    case tokyoMetroHonancho = "TokyoMetro.Honancho"
    case tokyoMetroIkebukuro = "TokyoMetro.Ikebukuro"
    case tokyoMetroKitaAyase = "TokyoMetro.KitaAyase"
    case tokyoMetroKitaSenju = "TokyoMetro.KitaSenju"
    case tokyoMetroMeguro = "TokyoMetro.Meguro"
    case tokyoMetroNakaMeguro = "TokyoMetro.NakaMeguro"
    case tokyoMetroNakano = "TokyoMetro.Nakano"
    case tokyoMetroNakanoSakaue = "TokyoMetro.NakanoSakaue"
    case tokyoMetroNishiFunabashi = "TokyoMetro.NishiFunabashi"
    case tokyoMetroOgikubo = "TokyoMetro.Ogikubo"
    case tokyoMetroOshiage = "TokyoMetro.Oshiage"
    case tokyoMetroShibuya = "TokyoMetro.Shibuya"
    case tokyoMetroShinKiba = "TokyoMetro.ShinKiba"
    case tokyoMetroWakoshi = "TokyoMetro.Wakoshi"
    case tokyoMetroYoyogiUehara = "TokyoMetro.YoyogiUehara"
    case jrEastKaihimmakuhari = "JR-East.Kaihimmakuhari"
    case jrEastNishiFunabashi = "JR-East.NishiFunabashi"
    case jrEastTokyo = "JR-East.Tokyo"

    public var id: Self { self }

    // Sort by order of cases above
    public static func < (lhs: RailDirection, rhs: RailDirection) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

extension RailDirection {
    var titleJA: String {
        switch self {
        case .inbound: "上り"
        case .outbound: "下り"
        case .northbound: "北行"
        case .southbound: "南行"
        case .eastbound: "東行"
        case .westbound: "西行"
        case .innerLoop: "内回り"
        case .outerLoop: "外回り"
        case .toeiMinowabashi: "三ノ輪橋"
        case .toeiWaseda: "早稲田"
        case .tokyoMetroAkabaneIwabushi: "赤羽岩淵"
        case .tokyoMetroAsakusa: "浅草"
        case .tokyoMetroHonancho: "方南町"
        case .tokyoMetroIkebukuro: "池袋"
        case .tokyoMetroKitaAyase: "北綾瀬"
        case .tokyoMetroKitaSenju: "北千住"
        case .tokyoMetroMeguro: "目黒"
        case .tokyoMetroNakaMeguro: "中目黒"
        case .tokyoMetroNakano: "中野"
        case .tokyoMetroNakanoSakaue: "中野坂上"
        case .tokyoMetroNishiFunabashi: "西船橋"
        case .tokyoMetroOgikubo: "荻窪"
        case .tokyoMetroOshiage: "押上〈スカイツリー前〉"
        case .tokyoMetroShibuya: "渋谷"
        case .tokyoMetroShinKiba: "新木場"
        case .tokyoMetroWakoshi: "和光市"
        case .tokyoMetroYoyogiUehara: "代々木上原"
        case .jrEastKaihimmakuhari: "海浜幕張方面"
        case .jrEastNishiFunabashi: "西船橋方面"
        case .jrEastTokyo: "東京方面"
        }
    }
}
