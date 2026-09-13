import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private struct CoverageExport: Decodable {
    let data: [CoverageData]
}

private struct CoverageData: Decodable {
    let totals: CoverageTotals
}

private struct CoverageTotals: Decodable {
    let lines: LineCoverage
}

private struct LineCoverage: Decodable {
    let percent: Double
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: coverage_gate.swift <summary.json> <minimum-percent>")
}

guard let minimum = Double(CommandLine.arguments[2]) else {
    fail("minimum coverage must be numeric")
}

do {
    let payload = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let export = try JSONDecoder().decode(CoverageExport.self, from: payload)
    guard let coverage = export.data.first?.totals.lines.percent else {
        fail("coverage summary contains no line total")
    }
    print(String(format: "TableSlateCore line coverage: %.2f%% (minimum %.2f%%)", coverage, minimum))
    if coverage + 1e-9 < minimum {
        exit(1)
    }
} catch {
    fail("cannot read coverage summary: \(error.localizedDescription)")
}
