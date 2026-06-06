import Testing
@testable import Kojeni

@Suite
struct EnumsTests {

    @Test func breast_opposite_left_returns_right() {
        #expect(Breast.left.opposite == .right)
    }

    @Test func breast_opposite_right_returns_left() {
        #expect(Breast.right.opposite == .left)
    }

    @Test func breast_opposite_is_involution() {
        #expect(Breast.left.opposite.opposite == .left)
        #expect(Breast.right.opposite.opposite == .right)
    }
}
