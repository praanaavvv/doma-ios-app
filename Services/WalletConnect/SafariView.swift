//
//  SafariView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 02/01/26.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.modalPresentationStyle = .pageSheet
        return vc
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}
