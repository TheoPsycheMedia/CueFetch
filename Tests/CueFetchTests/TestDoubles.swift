import Foundation
@testable import CueFetch

actor ScriptedAnalysisRunner: AnalysisRunner {
    enum Outcome: Equatable, Sendable {
        case success(Data)
        case failure(AnalysisRunnerError)
        case suspendedSuccess(Data)
    }

    private let outcome: Outcome
    private var requests: [AnalysisExecutionRequest] = []
    private var suspendedCaptures: [(
        data: Data,
        continuation: CheckedContinuation<Data, Never>
    )] = []

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func capture(_ request: AnalysisExecutionRequest) async throws -> Data {
        requests.append(request)
        switch outcome {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        case let .suspendedSuccess(data):
            return await withCheckedContinuation { continuation in
                suspendedCaptures.append((data, continuation))
            }
        }
    }

    func receivedRequests() -> [AnalysisExecutionRequest] {
        requests
    }

    func resumeSuspendedCaptures() {
        let captures = suspendedCaptures
        suspendedCaptures.removeAll()
        for capture in captures {
            capture.continuation.resume(returning: capture.data)
        }
    }
}

actor ScriptedDownloadRunner: DownloadRunner {
    struct Script: Equatable, Sendable {
        let events: [DownloadRunnerEvent]
        let result: DownloadRunnerResult
        let suspendUntilCancelled: Bool

        init(
            events: [DownloadRunnerEvent],
            result: DownloadRunnerResult,
            suspendUntilCancelled: Bool = false
        ) {
            self.events = events
            self.result = result
            self.suspendUntilCancelled = suspendUntilCancelled
        }
    }

    private let script: Script
    private var requests: [DownloadExecutionRequest] = []
    private var cancelledRunIDs: Set<UUID> = []
    private var cancellationWaiters: [
        UUID: CheckedContinuation<DownloadRunnerResult, Never>
    ] = [:]

    init(script: Script) {
        self.script = script
    }

    func run(
        _ request: DownloadExecutionRequest,
        onEvent: @escaping @Sendable (DownloadRunnerEvent) -> Void
    ) async -> DownloadRunnerResult {
        requests.append(request)
        guard !cancelledRunIDs.contains(request.runID), !Task.isCancelled else {
            return .cancelled
        }

        for event in script.events {
            guard !cancelledRunIDs.contains(request.runID), !Task.isCancelled else {
                return .cancelled
            }
            onEvent(event)
            await Task.yield()
        }

        if script.suspendUntilCancelled {
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    if cancelledRunIDs.contains(request.runID) {
                        continuation.resume(returning: .cancelled)
                    } else {
                        cancellationWaiters[request.runID] = continuation
                    }
                }
            } onCancel: {
                Task {
                    await self.cancel(runID: request.runID)
                }
            }
        }

        return script.result
    }

    func cancel(runID: UUID) {
        cancelledRunIDs.insert(runID)
        cancellationWaiters.removeValue(forKey: runID)?.resume(returning: .cancelled)
    }

    func receivedRequests() -> [DownloadExecutionRequest] {
        requests
    }
}
