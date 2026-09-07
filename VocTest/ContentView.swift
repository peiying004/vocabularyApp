import SwiftUI

/// App 的根 view：提供全域的 NavigationStack，並以 HomeView 作為導覽起點。
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}
