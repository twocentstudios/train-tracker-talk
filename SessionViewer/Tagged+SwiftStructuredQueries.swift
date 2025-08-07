import StructuredQueries
import Tagged

/// File copied from swift-structured-queries/Sources/StructuredQueriesCore/Traits/Tagged.swift
///
/// Xcode does not support SPM traits yet (???)

extension Tagged: @retroactive _OptionalPromotable where RawValue: _OptionalPromotable {}

extension Tagged: @retroactive QueryBindable where RawValue: QueryBindable {}

extension Tagged: @retroactive QueryDecodable where RawValue: QueryDecodable {}

extension Tagged: @retroactive QueryExpression where RawValue: QueryExpression {
    public var queryFragment: QueryFragment {
        rawValue.queryFragment
    }
}

extension Tagged: @retroactive QueryRepresentable where RawValue: QueryRepresentable {
    public typealias QueryOutput = Tagged<Tag, RawValue.QueryOutput>

    public var queryOutput: QueryOutput {
        QueryOutput(rawValue: rawValue.queryOutput)
    }

    public init(queryOutput: QueryOutput) {
        self.init(rawValue: RawValue(queryOutput: queryOutput.rawValue))
    }
}

extension Tagged: @retroactive SQLiteType where RawValue: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
        RawValue.typeAffinity
    }
}
