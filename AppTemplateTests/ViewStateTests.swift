@testable import AppTemplate
import Testing

/// One file testing the one shared type — not five numbered files testing five
/// hand-duplicated ones (see README's "Architecture rules" for why that's the thing
/// being avoided here).
struct ViewStateTests {
    @Test
    func valueIsPresentForLoadedAndRefreshing() {
        #expect(ViewState.loaded(1).value == 1)
        #expect(ViewState.refreshing(2).value == 2)
    }

    @Test
    func valueIsNilForLoadingAndFailed() {
        #expect(ViewState<Int>.loading.value == nil)
        #expect(ViewState<Int>.failed("x").value == nil)
    }
}
