/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Quick
import Nimble
import Foundation

@testable import lockbox_ios

class OAuthInfoSpec: QuickSpec {
    override func spec() {
        describe("builder") {
            it("builds the OAuthInfo with all the provided parameters") {
                let uid = "something"
                let email = "something"
                let accessToken = "something"
                let expiresAt = Date()
                let refreshToken = "something"
                let idToken = "something"
                let scopedKey = "something"

                let info = OAuthInfo.Builder()
                        .uid(uid)
                        .email(email)
                        .accessToken(accessToken)
                        .expiresAt(expiresAt)
                        .refreshToken(refreshToken)
                        .idToken(idToken)
                        .scopedKey(scopedKey)
                        .build()

                expect(info.uid).to(equal(uid))
                expect(info.email).to(equal(email))
                expect(info.accessToken).to(equal(accessToken))
                expect(info.expiresAt).to(equal(expiresAt))
                expect(info.refreshToken).to(equal(refreshToken))
                expect(info.idToken).to(equal(idToken))
                expect(info.scopedKey).to(equal(scopedKey))
            }
        }
    }
}