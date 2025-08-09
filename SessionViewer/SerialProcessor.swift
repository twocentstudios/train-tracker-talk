import Foundation

final class SerialProcessor<Input: Sendable, Output: Sendable> {
    typealias Process = @Sendable (Input) async -> Output

    // Inbound (sync) and outbound (single-consumer) pipes
    private let inPair: (stream: AsyncStream<Input>, continuation: AsyncStream<Input>.Continuation)
    private let outPair: (stream: AsyncStream<Output>, continuation: AsyncStream<Output>.Continuation)

    private let worker: Task<Void, Never>
    private let process: Process

    /// Single-consumer stream of `Output`.
    var results: AsyncStream<Output> { outPair.stream }

    init(
        inputBuffering: AsyncStream<Input>.Continuation.BufferingPolicy = .unbounded,
        outputBuffering: AsyncStream<Output>.Continuation.BufferingPolicy = .unbounded,
        process: @escaping Process
    ) {
        print("ASDF SerialProcessor init")
        self.process = process

        let inPair = AsyncStream.makeStream(of: Input.self, bufferingPolicy: inputBuffering)
        let outPair = AsyncStream.makeStream(of: Output.self, bufferingPolicy: outputBuffering)
        self.inPair = inPair
        self.outPair = outPair

        worker = Task {
            for await input in inPair.stream {
                let output = await process(input)
                outPair.continuation.yield(output)
            }
            outPair.continuation.finish()
        }
    }

    deinit {
        print("ASDF SerialProcessor deinit")
        finish()
    }

    func submit(_ input: Input) {
        inPair.continuation.yield(input)
    }

    func finish() {
        inPair.continuation.finish()
        worker.cancel()
    }
}
