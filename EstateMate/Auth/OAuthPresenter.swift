//
//  OAuthPresenter.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import AuthenticationServices
import UIKit

final class OAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresenter()
    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackURLScheme: String) {
        let s = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { _, _ in
            // callback handled in .onOpenURL at app level
        }

        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = true
        self.session = s
        s.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
