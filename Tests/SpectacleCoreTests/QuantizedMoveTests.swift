import Testing
import CoreGraphics
@testable import SpectacleCore

// Cocoa frames. Each test first makes the standard move (one write of `requested`), then hands
// what the window took to the quantized step, as `WindowMover` does.
private let rightHalf = CGRect(x: 720, y: 0, width: 720, height: 875)

private func fit(_ window: SimulatedWindow, to requested: CGRect) -> CGRect? {
    guard let actual = window.resize(requested) else { return nil }
    return QuantizedMove.fit(requested: requested, actual: actual, resize: window.resize)
}

@Test func terminalRoundingUpToCellsIsShrunkIntoTheTileAndCentred() {
    // 7×14 pt cells: 720×875 comes out 721×882. Shrinking 2 pt a step: 718×873 → 721×882,
    // 716×871 → 721×882, 714×869 → 714×882, then only the height, 714×867 → 714×868, which fits.
    // Centred: floor((720 - 714) / 2) = 3 in from the left, floor((875 - 868) / 2) = 3 down.
    let window = SimulatedWindow(.zero, size: SimulatedWindow.cells(CGSize(width: 7, height: 14)))
    let settled = fit(window, to: rightHalf)
    #expect(settled == CGRect(x: 723, y: 4, width: 714, height: 868))
    #expect(window.frame == settled)
    #expect(window.writes.map(\.size) == [
        CGSize(width: 720, height: 875),                                   // standard move
        CGSize(width: 718, height: 873), CGSize(width: 716, height: 871),
        CGSize(width: 714, height: 869), CGSize(width: 714, height: 867),
        CGSize(width: 714, height: 867),                                   // centring
    ])
}

@Test func windowThatTookTheRectNeedsNoFurtherWrite() {
    let window = SimulatedWindow(.zero)
    #expect(fit(window, to: rightHalf) == rightHalf)
    #expect(window.writes == [rightHalf])
}

@Test func windowThatKeepsChangingButNeverFitsStopsAtTheFloor() {
    // Always 200 pt wider than asked: it changes on every write, so only the floor stops it. The
    // request shrinks 718, 716 … 614. The next step, 612, is under the original's floor of
    // 720 × 0.85f (612.00002), so the loop stops without writing it; the centring write then
    // carries it, as the original's did. Centred on the last read, 814 wide:
    // floor((720 - 814) / 2) = -47.
    let window = SimulatedWindow(.zero, size: { CGSize(width: $0.width + 200, height: $0.height) })
    let settled = fit(window, to: rightHalf)
    #expect(settled == CGRect(x: 673, y: 0, width: 812, height: 875))
    #expect(window.writes.dropFirst().map(\.width) == Array(stride(from: 718, through: 614, by: -2)) + [612])
}

@Test func windowThatIgnoresTheShrinkStopsAfter32Points() {
    // Never narrower than 1000: 16 writes (718 … 688) leave it 1000 wide, so the loop gives up
    // instead of walking on to the floor. The centring write keeps the last size, 688, and
    // centres on the tile: floor((720 - 1000) / 2) = -140.
    let window = SimulatedWindow(.zero, size: SimulatedWindow.minimum(CGSize(width: 1000, height: 0)))
    let settled = fit(window, to: rightHalf)
    #expect(settled == CGRect(x: 580, y: 0, width: 1000, height: 875))
    #expect(window.writes.dropFirst().map(\.width) == Array(stride(from: 718, through: 688, by: -2)) + [688])
}

@Test func terminalWithTallCellsStillShrinksIntoTheTile() {
    // 20 pt rows: 879 comes out 880, and the height must drop 19 pt to reach 860. Nine writes
    // (877 … 861) leave it 880, 18 pt ignored, still under the 32 pt limit; 859 gives 860.
    // Centred: floor((879 - 860) / 2) = 9 down.
    let tile = CGRect(x: 720, y: 0, width: 720, height: 879)
    let window = SimulatedWindow(.zero, size: SimulatedWindow.cells(CGSize(width: 10, height: 20)))
    #expect(fit(window, to: tile) == CGRect(x: 720, y: 10, width: 720, height: 860))
    #expect(window.writes.dropFirst().map(\.height) == Array(stride(from: 877, through: 859, by: -2)) + [859])
}

@Test func windowSmallerThanTheRectIsCentredOnIt() {
    // A fixed-size window keeps its size; the original centred it on the tile.
    let window = SimulatedWindow(.zero, size: { _ in CGSize(width: 400, height: 300) })
    #expect(fit(window, to: rightHalf) == CGRect(x: 880, y: 288, width: 400, height: 300))
    #expect(window.writes.count == 2)
}

@Test func windowThatCanNoLongerBeReadStopsTheLoop() {
    var writes = 0
    let settled = QuantizedMove.fit(requested: rightHalf, actual: rightHalf.insetBy(dx: -5, dy: -5)) { _ in
        writes += 1
        return nil
    }
    #expect(settled == nil)
    #expect(writes == 1)
}
