import Foundation
import Testing
import LegadoCore
@testable import LegadoAppModels

@MainActor
struct SourceLibraryFilterTests {
    @Test func derivedStateTracksGroupsCountsAndLookup() async {
        var first = BookSource(bookSourceUrl: "http://www.365xiaoshuo.org", bookSourceName: "天天小说")
        first.bookSourceGroup = "小说,玄幻"
        first.enabled = true

        var second = BookSource(bookSourceUrl: "https://example.org", bookSourceName: "示例书源")
        second.bookSourceGroup = "玄幻"
        second.enabled = false

        var third = BookSource(bookSourceUrl: "https://ungrouped.example", bookSourceName: "未分组源")
        third.bookSourceGroup = nil
        third.enabled = true

        let model = SourceLibraryModel.demo(sources: [first, second, third])
        await model.load()

        #expect(model.enabledCount == 2)
        #expect(model.groups == ["小说", "玄幻"])
        #expect(model.groupCounts["小说"] == 1)
        #expect(model.groupCounts["玄幻"] == 2)
        #expect(model.source(id: first.id)?.bookSourceName == "天天小说")
        #expect(model.summaries.count == 3)

        await model.setEnabled(false, for: first.id)
        #expect(model.enabledCount == 1)
        #expect(model.source(id: first.id)?.enabled == false)
    }

    @Test func filterSummariesMatchesDomainNameAndGroupAcrossLargeLibrary() async {
        var sources: [BookSource] = (0..<2500).map { index in
            var source = BookSource(
                bookSourceUrl: "https://site\(index).example.com",
                bookSourceName: "测试书源 \(index)"
            )
            source.bookSourceGroup = index.isMultiple(of: 5) ? "精品" : nil
            source.weight = 2500 - index
            return source
        }
        var target = BookSource(bookSourceUrl: "http://www.365xiaoshuo.org", bookSourceName: "天天小说")
        target.bookSourceGroup = "小说"
        sources.append(target)

        let model = SourceLibraryModel.demo(sources: sources)
        await model.load()

        let byDomain = SourceLibraryModel.filterSummaries(
            model.summaries,
            selectedGroup: nil,
            searchText: "365XIAOSHUO",
            sortMode: "manual",
            descending: false
        )
        #expect(byDomain.map(\.id) == [target.id])

        let byGroup = SourceLibraryModel.filterSummaries(
            model.summaries,
            selectedGroup: "小说",
            searchText: "",
            sortMode: "manual",
            descending: false
        )
        #expect(byGroup.map(\.id) == [target.id])

        let ungrouped = SourceLibraryModel.filterSummaries(
            model.summaries,
            selectedGroup: "",
            searchText: "site1.",
            sortMode: "manual",
            descending: false
        )
        #expect(ungrouped.map(\.id) == ["https://site1.example.com"])
    }
}
