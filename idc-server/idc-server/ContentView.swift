//
//  ContentView.swift
//  idc-server
//
//  Created by Shik Chen on 2026/1/10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
            .tabItem {
                Label("Home", systemImage: "house")
            }

            TestFixtureView()
                .tabItem {
                    Label("Test", systemImage: "hammer")
                }
        }
    }
}

#Preview {
    ContentView()
}
