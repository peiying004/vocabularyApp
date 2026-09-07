import Foundation

extension Array {
    /// 把陣列切成每段最多 `size` 個元素的子陣列（最後一段可能不足 `size`）。
    /// 匯入時用來把解析出的卡片／題目依固定批次大小切批，例如
    /// `[1,2,3,4,5].chunked(into: 2)` → `[[1,2],[3,4],[5]]`。
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
