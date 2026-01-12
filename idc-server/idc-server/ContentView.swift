//
//  ContentView.swift
//  idc-server
//
//  Created by Shik Chen on 2026/1/10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if ProcessInfo.processInfo.environment["IDC_TEST_MODE"] == "1" {
            TestFixtureView()
        } else {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
