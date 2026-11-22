//
//  PairedBracket.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A paired bracket of UAX #9, its Bidi_Paired_Bracket_Type and the opening bracket of its pair, which rule N0 matches
// brackets by. The opening bracket is canonically decomposed, so a bracket pairs with the canonical equivalent of its
// pair. The table is the Unicode 17.0.0 data of BidiBrackets.txt, which `source/bidi-data.py` writes.
struct PairedBracket: Equatable, Sendable {
    enum BracketType: Equatable, Sendable {
        case opening
        case closing
    }

    // MARK: - Property
    let type: BracketType
    let opening: UInt32

    private static let brackets: [UInt32: PairedBracket] = [
        0x0028: PairedBracket(type: .opening, opening: 0x0028), 0x0029: PairedBracket(type: .closing, opening: 0x0028),
        0x005B: PairedBracket(type: .opening, opening: 0x005B), 0x005D: PairedBracket(type: .closing, opening: 0x005B),
        0x007B: PairedBracket(type: .opening, opening: 0x007B), 0x007D: PairedBracket(type: .closing, opening: 0x007B),
        0x0F3A: PairedBracket(type: .opening, opening: 0x0F3A), 0x0F3B: PairedBracket(type: .closing, opening: 0x0F3A),
        0x0F3C: PairedBracket(type: .opening, opening: 0x0F3C), 0x0F3D: PairedBracket(type: .closing, opening: 0x0F3C),
        0x169B: PairedBracket(type: .opening, opening: 0x169B), 0x169C: PairedBracket(type: .closing, opening: 0x169B),
        0x2045: PairedBracket(type: .opening, opening: 0x2045), 0x2046: PairedBracket(type: .closing, opening: 0x2045),
        0x207D: PairedBracket(type: .opening, opening: 0x207D), 0x207E: PairedBracket(type: .closing, opening: 0x207D),
        0x208D: PairedBracket(type: .opening, opening: 0x208D), 0x208E: PairedBracket(type: .closing, opening: 0x208D),
        0x2308: PairedBracket(type: .opening, opening: 0x2308), 0x2309: PairedBracket(type: .closing, opening: 0x2308),
        0x230A: PairedBracket(type: .opening, opening: 0x230A), 0x230B: PairedBracket(type: .closing, opening: 0x230A),
        0x2329: PairedBracket(type: .opening, opening: 0x3008), 0x232A: PairedBracket(type: .closing, opening: 0x3008),
        0x2768: PairedBracket(type: .opening, opening: 0x2768), 0x2769: PairedBracket(type: .closing, opening: 0x2768),
        0x276A: PairedBracket(type: .opening, opening: 0x276A), 0x276B: PairedBracket(type: .closing, opening: 0x276A),
        0x276C: PairedBracket(type: .opening, opening: 0x276C), 0x276D: PairedBracket(type: .closing, opening: 0x276C),
        0x276E: PairedBracket(type: .opening, opening: 0x276E), 0x276F: PairedBracket(type: .closing, opening: 0x276E),
        0x2770: PairedBracket(type: .opening, opening: 0x2770), 0x2771: PairedBracket(type: .closing, opening: 0x2770),
        0x2772: PairedBracket(type: .opening, opening: 0x2772), 0x2773: PairedBracket(type: .closing, opening: 0x2772),
        0x2774: PairedBracket(type: .opening, opening: 0x2774), 0x2775: PairedBracket(type: .closing, opening: 0x2774),
        0x27C5: PairedBracket(type: .opening, opening: 0x27C5), 0x27C6: PairedBracket(type: .closing, opening: 0x27C5),
        0x27E6: PairedBracket(type: .opening, opening: 0x27E6), 0x27E7: PairedBracket(type: .closing, opening: 0x27E6),
        0x27E8: PairedBracket(type: .opening, opening: 0x27E8), 0x27E9: PairedBracket(type: .closing, opening: 0x27E8),
        0x27EA: PairedBracket(type: .opening, opening: 0x27EA), 0x27EB: PairedBracket(type: .closing, opening: 0x27EA),
        0x27EC: PairedBracket(type: .opening, opening: 0x27EC), 0x27ED: PairedBracket(type: .closing, opening: 0x27EC),
        0x27EE: PairedBracket(type: .opening, opening: 0x27EE), 0x27EF: PairedBracket(type: .closing, opening: 0x27EE),
        0x2983: PairedBracket(type: .opening, opening: 0x2983), 0x2984: PairedBracket(type: .closing, opening: 0x2983),
        0x2985: PairedBracket(type: .opening, opening: 0x2985), 0x2986: PairedBracket(type: .closing, opening: 0x2985),
        0x2987: PairedBracket(type: .opening, opening: 0x2987), 0x2988: PairedBracket(type: .closing, opening: 0x2987),
        0x2989: PairedBracket(type: .opening, opening: 0x2989), 0x298A: PairedBracket(type: .closing, opening: 0x2989),
        0x298B: PairedBracket(type: .opening, opening: 0x298B), 0x298C: PairedBracket(type: .closing, opening: 0x298B),
        0x298D: PairedBracket(type: .opening, opening: 0x298D), 0x298E: PairedBracket(type: .closing, opening: 0x298F),
        0x298F: PairedBracket(type: .opening, opening: 0x298F), 0x2990: PairedBracket(type: .closing, opening: 0x298D),
        0x2991: PairedBracket(type: .opening, opening: 0x2991), 0x2992: PairedBracket(type: .closing, opening: 0x2991),
        0x2993: PairedBracket(type: .opening, opening: 0x2993), 0x2994: PairedBracket(type: .closing, opening: 0x2993),
        0x2995: PairedBracket(type: .opening, opening: 0x2995), 0x2996: PairedBracket(type: .closing, opening: 0x2995),
        0x2997: PairedBracket(type: .opening, opening: 0x2997), 0x2998: PairedBracket(type: .closing, opening: 0x2997),
        0x29D8: PairedBracket(type: .opening, opening: 0x29D8), 0x29D9: PairedBracket(type: .closing, opening: 0x29D8),
        0x29DA: PairedBracket(type: .opening, opening: 0x29DA), 0x29DB: PairedBracket(type: .closing, opening: 0x29DA),
        0x29FC: PairedBracket(type: .opening, opening: 0x29FC), 0x29FD: PairedBracket(type: .closing, opening: 0x29FC),
        0x2E22: PairedBracket(type: .opening, opening: 0x2E22), 0x2E23: PairedBracket(type: .closing, opening: 0x2E22),
        0x2E24: PairedBracket(type: .opening, opening: 0x2E24), 0x2E25: PairedBracket(type: .closing, opening: 0x2E24),
        0x2E26: PairedBracket(type: .opening, opening: 0x2E26), 0x2E27: PairedBracket(type: .closing, opening: 0x2E26),
        0x2E28: PairedBracket(type: .opening, opening: 0x2E28), 0x2E29: PairedBracket(type: .closing, opening: 0x2E28),
        0x2E55: PairedBracket(type: .opening, opening: 0x2E55), 0x2E56: PairedBracket(type: .closing, opening: 0x2E55),
        0x2E57: PairedBracket(type: .opening, opening: 0x2E57), 0x2E58: PairedBracket(type: .closing, opening: 0x2E57),
        0x2E59: PairedBracket(type: .opening, opening: 0x2E59), 0x2E5A: PairedBracket(type: .closing, opening: 0x2E59),
        0x2E5B: PairedBracket(type: .opening, opening: 0x2E5B), 0x2E5C: PairedBracket(type: .closing, opening: 0x2E5B),
        0x3008: PairedBracket(type: .opening, opening: 0x3008), 0x3009: PairedBracket(type: .closing, opening: 0x3008),
        0x300A: PairedBracket(type: .opening, opening: 0x300A), 0x300B: PairedBracket(type: .closing, opening: 0x300A),
        0x300C: PairedBracket(type: .opening, opening: 0x300C), 0x300D: PairedBracket(type: .closing, opening: 0x300C),
        0x300E: PairedBracket(type: .opening, opening: 0x300E), 0x300F: PairedBracket(type: .closing, opening: 0x300E),
        0x3010: PairedBracket(type: .opening, opening: 0x3010), 0x3011: PairedBracket(type: .closing, opening: 0x3010),
        0x3014: PairedBracket(type: .opening, opening: 0x3014), 0x3015: PairedBracket(type: .closing, opening: 0x3014),
        0x3016: PairedBracket(type: .opening, opening: 0x3016), 0x3017: PairedBracket(type: .closing, opening: 0x3016),
        0x3018: PairedBracket(type: .opening, opening: 0x3018), 0x3019: PairedBracket(type: .closing, opening: 0x3018),
        0x301A: PairedBracket(type: .opening, opening: 0x301A), 0x301B: PairedBracket(type: .closing, opening: 0x301A),
        0xFE59: PairedBracket(type: .opening, opening: 0xFE59), 0xFE5A: PairedBracket(type: .closing, opening: 0xFE59),
        0xFE5B: PairedBracket(type: .opening, opening: 0xFE5B), 0xFE5C: PairedBracket(type: .closing, opening: 0xFE5B),
        0xFE5D: PairedBracket(type: .opening, opening: 0xFE5D), 0xFE5E: PairedBracket(type: .closing, opening: 0xFE5D),
        0xFF08: PairedBracket(type: .opening, opening: 0xFF08), 0xFF09: PairedBracket(type: .closing, opening: 0xFF08),
        0xFF3B: PairedBracket(type: .opening, opening: 0xFF3B), 0xFF3D: PairedBracket(type: .closing, opening: 0xFF3B),
        0xFF5B: PairedBracket(type: .opening, opening: 0xFF5B), 0xFF5D: PairedBracket(type: .closing, opening: 0xFF5B),
        0xFF5F: PairedBracket(type: .opening, opening: 0xFF5F), 0xFF60: PairedBracket(type: .closing, opening: 0xFF5F),
        0xFF62: PairedBracket(type: .opening, opening: 0xFF62), 0xFF63: PairedBracket(type: .closing, opening: 0xFF62)
    ]

    // MARK: - Initializer
    private init(type: BracketType, opening: UInt32) {
        self.type = type
        self.opening = opening
    }

    init?(_ scalar: Unicode.Scalar) {
        guard let bracket = Self.brackets[scalar.value] else { return nil }

        self = bracket
    }

    // MARK: - Public
    // MARK: - Private
}
