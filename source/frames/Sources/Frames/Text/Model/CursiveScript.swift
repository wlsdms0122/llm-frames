//
//  CursiveScript.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// The cursive scripts a scalar belongs to by its Script and Script_Extensions values, as their ISO 15924 codes in
// order, as CSS Text 3 reads a character's script with its Script_Extensions. A script is cursive when one of its
// characters is dual-joining (Joining_Type D) in ArabicShaping.txt, so the cursive scripts are
// Adlm, Arab, Chrs, Mand, Mani, Mong, Nkoo, Ougr, Phag, Phlp, Rohg, Sogd, Syrc.
// Swift gives no Script property, so the table is the Unicode 17.0.0 data of Scripts.txt, ScriptExtensions.txt
// and ArabicShaping.txt, which `source/cursive-data.py` writes.
enum CursiveScript {
    // MARK: - Property
    // The first scalar of each stretch of scalars that share their cursive scripts, in order, and the cursive scripts
    // of each stretch.
    private static let starts: [UInt32] = [
        0x0000, 0x0303, 0x0305, 0x0307, 0x0309, 0x030A, 0x030B, 0x0323, 0x0326, 0x032D, 0x032F, 0x0330, 0x0332, 0x0600,
        0x0605, 0x0606, 0x060C, 0x060D, 0x061B, 0x061C, 0x061D, 0x061F, 0x0620, 0x0640, 0x0641, 0x064B, 0x0656, 0x0670,
        0x0671, 0x06D4, 0x06D5, 0x06DD, 0x06DE, 0x0700, 0x070E, 0x070F, 0x074B, 0x074D, 0x0750, 0x0780, 0x07C0, 0x07FB,
        0x07FD, 0x0800, 0x0840, 0x085C, 0x085E, 0x085F, 0x0860, 0x086B, 0x0870, 0x0892, 0x0897, 0x08E2, 0x08E3, 0x0900,
        0x1800, 0x1802, 0x1804, 0x1805, 0x1806, 0x181A, 0x1820, 0x1879, 0x1880, 0x18AB, 0x1DF8, 0x1DF9, 0x1DFA, 0x1DFB,
        0x202F, 0x2030, 0x204F, 0x2050, 0x2E41, 0x2E42, 0x3001, 0x3002, 0x3003, 0x3008, 0x300C, 0xA840, 0xA878, 0xFB50,
        0xFD3E, 0xFD40, 0xFDD0, 0xFDF0, 0xFE00, 0xFE70, 0xFE75, 0xFE76, 0xFEFD, 0x102E0, 0x102FC, 0x10AC0, 0x10AE7,
        0x10AEB, 0x10AF2, 0x10AF3, 0x10AF7, 0x10B80, 0x10B92, 0x10B99, 0x10B9D, 0x10BA9, 0x10BB0, 0x10D00, 0x10D28,
        0x10D30, 0x10D3A, 0x10E60, 0x10E7F, 0x10EC2, 0x10EC8, 0x10ED0, 0x10ED9, 0x10EFA, 0x10F00, 0x10F30, 0x10F5A,
        0x10F70, 0x10F8A, 0x10FB0, 0x10FCC, 0x11660, 0x1166D, 0x1E900, 0x1E94C, 0x1E950, 0x1E95A, 0x1E95E, 0x1E960,
        0x1EE00, 0x1EE04, 0x1EE05, 0x1EE20, 0x1EE21, 0x1EE23, 0x1EE24, 0x1EE25, 0x1EE27, 0x1EE28, 0x1EE29, 0x1EE33,
        0x1EE34, 0x1EE38, 0x1EE39, 0x1EE3A, 0x1EE3B, 0x1EE3C, 0x1EE42, 0x1EE43, 0x1EE47, 0x1EE48, 0x1EE49, 0x1EE4A,
        0x1EE4B, 0x1EE4C, 0x1EE4D, 0x1EE50, 0x1EE51, 0x1EE53, 0x1EE54, 0x1EE55, 0x1EE57, 0x1EE58, 0x1EE59, 0x1EE5A,
        0x1EE5B, 0x1EE5C, 0x1EE5D, 0x1EE5E, 0x1EE5F, 0x1EE60, 0x1EE61, 0x1EE63, 0x1EE64, 0x1EE65, 0x1EE67, 0x1EE6B,
        0x1EE6C, 0x1EE73, 0x1EE74, 0x1EE78, 0x1EE79, 0x1EE7D, 0x1EE7E, 0x1EE7F, 0x1EE80, 0x1EE8A, 0x1EE8B, 0x1EE9C,
        0x1EEA1, 0x1EEA4, 0x1EEA5, 0x1EEAA, 0x1EEAB, 0x1EEBC, 0x1EEF0, 0x1EEF2
    ]
    private static let scripts: [[String]] = [
        [], ["Syrc"], [], ["Syrc"], [], ["Syrc"], [], ["Syrc"], [], ["Syrc"], [], ["Syrc"], [], ["Arab"], [], ["Arab"],
        ["Arab", "Nkoo", "Rohg", "Syrc"], ["Arab"], ["Arab", "Nkoo", "Rohg", "Syrc"], ["Arab", "Syrc"], ["Arab"],
        ["Adlm", "Arab", "Nkoo", "Rohg", "Syrc"], ["Arab"],
        ["Adlm", "Arab", "Mand", "Mani", "Ougr", "Phlp", "Rohg", "Sogd", "Syrc"], ["Arab"], ["Arab", "Syrc"], ["Arab"],
        ["Arab", "Syrc"], ["Arab"], ["Arab", "Rohg"], ["Arab"], [], ["Arab"], ["Syrc"], [], ["Syrc"], [], ["Syrc"],
        ["Arab"], [], ["Nkoo"], [], ["Nkoo"], [], ["Mand"], [], ["Mand"], [], ["Syrc"], [], ["Arab"], [], ["Arab"], [],
        ["Arab"], [], ["Mong"], ["Mong", "Phag"], ["Mong"], ["Mong", "Phag"], ["Mong"], [], ["Mong"], [], ["Mong"], [],
        ["Syrc"], [], ["Syrc"], [], ["Mong", "Phag"], [], ["Adlm", "Arab"], [], ["Adlm", "Arab"], [], ["Mong"],
        ["Mong", "Phag"], [], ["Mong"], [], ["Phag"], [], ["Arab"], ["Arab", "Nkoo"], ["Arab"], [], ["Arab"], [],
        ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Mani"], [], ["Mani"], ["Mani", "Ougr"], ["Mani"], [], ["Phlp"], [],
        ["Phlp"], [], ["Phlp"], [], ["Rohg"], [], ["Rohg"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [],
        ["Sogd"], [], ["Ougr"], [], ["Chrs"], [], ["Mong"], [], ["Adlm"], [], ["Adlm"], [], ["Adlm"], [], ["Arab"], [],
        ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [],
        ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [],
        ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [],
        ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [], ["Arab"], [],
        ["Arab"], []
    ]

    // MARK: - Initializer
    // MARK: - Public
    static func codes(of scalar: Unicode.Scalar) -> [String] {
        var low = 0
        var high = Self.starts.count
        while high - low > 1 {
            let middle = (low + high) / 2
            if Self.starts[middle] <= scalar.value {
                low = middle
            } else {
                high = middle
            }
        }

        return Self.scripts[low]
    }

    // MARK: - Private
}
