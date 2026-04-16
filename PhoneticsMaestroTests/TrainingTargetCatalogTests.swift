import XCTest
@testable import PhoneticsCore

final class TrainingTargetCatalogTests: XCTestCase {
    func testSoundContrastTargetUsesContrastGroupAndExampleSummary() {
        let target = TrainingTargetSummary(
            id: "pair:ʌ-æ",
            group: .soundContrasts,
            title: "ʌ-æ",
            subtitle: "but / bat",
            currentItemType: "pair"
        )

        XCTAssertEqual(target.group.sectionTitle, "Sound Contrasts")
        XCTAssertEqual(target.displayLabel, "ʌ-æ")
        XCTAssertEqual(target.subtitle, "but / bat")
        XCTAssertEqual(target.currentItemType, "pair")
    }

    func testSentenceBackedCardUsesLeftAndRightSentenceTargets() {
        let card = TrainingCardItem(
            kind: .sentence(phenomenon: "linking"),
            itemType: "sentence",
            itemID: 1,
            targetID: "sentence:linking",
            title: "Linking",
            subtitle: "Pick it up.",
            leftText: "Pick it up.",
            leftIPA: "/pɪk‿ɪt‿ʌp/",
            rightText: "Turn it on.",
            rightIPA: "/tɜːn‿ɪt‿ɒn/",
            tierLabel: "Sentence"
        )

        XCTAssertEqual(card.kind, .sentence(phenomenon: "linking"))
        XCTAssertEqual(card.leftText, "Pick it up.")
        XCTAssertEqual(card.rightText, "Turn it on.")
        XCTAssertEqual(card.id, "sentence:1")
        XCTAssertEqual(card.kind.itemType, "sentence")
    }

    func testSelectorSectionsOmitEmptyGroupsAndPreserveDisplayOrder() {
        let targets = [
            TrainingTargetSummary(
                id: "sentence:linking",
                group: .linkingReduction,
                title: "Linking",
                subtitle: "connect words smoothly",
                currentItemType: "sentence"
            ),
            TrainingTargetSummary(
                id: "pair:ʌ-æ",
                group: .soundContrasts,
                title: "ʌ-æ",
                subtitle: "but / bat",
                currentItemType: "pair"
            ),
            TrainingTargetSummary(
                id: "pair:iː-ɪ",
                group: .soundContrasts,
                title: "iː-ɪ",
                subtitle: "sheep / ship",
                currentItemType: "pair"
            )
        ]

        let sections = TrainingTargetSelectorSection.sections(from: targets)

        XCTAssertEqual(sections.map(\.group), [.soundContrasts, .linkingReduction])
        XCTAssertEqual(sections[0].targets.map(\.id), ["pair:ʌ-æ", "pair:iː-ɪ"])
        XCTAssertEqual(sections[1].targets.map(\.id), ["sentence:linking"])
    }
}
