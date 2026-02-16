//
//  MainTabView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatsView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chats")
                }

            GroupChatView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Groups")
                }


            DomainsView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Domains")
                }

            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Analytics")
                }


            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }

        }
    }
}

// Temporary placeholders (we'll replace with real screens next)
struct ChatsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Chats UI coming next")
                .navigationTitle("Chats")
        }
    }
}

struct DomainsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Domains UI coming next")
                .navigationTitle("Domains")
        }
    }
}

struct AnalyticsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Analytics UI coming next")
                .navigationTitle("Analytics")
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Settings UI coming next")
                .navigationTitle("Settings")
        }
    }
}
