//
//  Publisher+toBlockingResult.swift
//  
//
//  Created by Kourouche, Mazen on 16/8/21.
//
import Foundation
import Combine

public extension Publisher {
    func toBlockingResult(timeout: Int) -> Result<[Self.Output],BlockingError> {
        var result : Result<[Self.Output],BlockingError>?
        let semaphore = DispatchSemaphore(value: 0)

        let sub = self
            .collect()
            .mapError { error in BlockingError.otherError(error) }
            .timeout(
                .seconds(timeout),
                scheduler: DispatchQueue.main,
                customError: { BlockingError.timeoutError(timeout) }
            ).sink(
                receiveCompletion: { compl in
                    switch compl {
                        case .finished: break
                        case .failure( let f ): result = .failure(f)
                    }
                    semaphore.signal()
                },
                receiveValue: { value in
                    result = .success(value)
                    semaphore.signal()
                }
            )

        // Wait for a result, or time out
        if semaphore.wait(timeout: .now() + .seconds(timeout)) == .timedOut {
            sub.cancel()
            return .failure(BlockingError.timeoutError(timeout))
        } else {
            return result ?? .success([])
        }
    }
}

public enum BlockingError : Error {
    case timeoutError(Int)
    case otherError(Error)
}
