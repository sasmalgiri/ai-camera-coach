//
//  SystemPhotoSaver.swift
//  AI Camera Coach
//
//  Saves processed photos to the user's iOS Photos library (opt-in).
//  Uses PHPhotoLibrary with `.addOnly` authorisation so we don't need
//  full library read access.
//

import Foundation
import Photos
import UIKit

@MainActor
enum SystemPhotoSaver {

    static func ensureAuthorisation() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited: return true
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return granted == .authorized || granted == .limited
        default: return false
        }
    }

    @discardableResult
    static func save(_ image: UIImage) async -> Bool {
        guard await ensureAuthorisation() else { return false }
        return await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                cont.resume(returning: success)
            }
        }
    }
}
