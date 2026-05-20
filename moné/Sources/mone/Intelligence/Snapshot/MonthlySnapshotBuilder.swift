import Foundation

final class MonthlySnapshotBuilder {
    
    private let parser = NarrationParser()
    private let classifier = TransactionClassifier()
    private let overrideResolver = ClassificationOverrideResolver()
    
    func buildSnapshots(
        for result: ImportResult,
        aiSuggestions: [String: AIClassificationSuggestion] = [:]
    ) -> [MonthlySnapshot] {
        let depositTransactions = result.transactions.filter {
            $0.accountType.lowercased() == "deposit"
        }
        
        let classifiedTransactions = depositTransactions.map { transaction in
            let parsed = parser.parse(transaction)
            let baseClassification = classifier.classify(
                transaction: transaction,
                parsed: parsed
            )
            
            let effectiveClassification = overrideResolver.resolve(
                base: baseClassification,
                aiSuggestion: aiSuggestions[transaction.id]
            )
            
            return ClassifiedTransaction(
                transaction: transaction,
                parsed: parsed,
                classification: effectiveClassification
            )
        }
        
        let groupedByMonth = Dictionary(grouping: classifiedTransactions) { item in
            monthKey(for: item.transaction) ?? "unknown"
        }
        
        return groupedByMonth
            .map { month, items in
                buildSnapshot(
                    personaId: result.personaId,
                    month: month,
                    items: items
                )
            }
            .sorted { $0.month < $1.month }
    }
    
    private func buildSnapshot(
        personaId: PersonaId,
        month: String,
        items: [ClassifiedTransaction]
    ) -> MonthlySnapshot {
        
        var income: Double = 0
        var committed: Double = 0
        var everyday: Double = 0
        var fund: Double = 0
        var liability: Double = 0
        var outliers: Double = 0
        var review: Double = 0
        
        var totalDebitAmount: Double = 0
        var classifiedDebitAmount: Double = 0
        var confidenceWeightedSum: Double = 0
        var reviewCount = 0
        
        for item in items {
            let transaction = item.transaction
            let classification = item.classification
            let amount = transaction.amount
            let type = transaction.type.uppercased()
            
            if classification.role == MoneRole.selfTransfer ||
                classification.role == MoneRole.assetTransfer ||
                classification.role == MoneRole.reimbursementOrRefund {
                continue
            }
                
                if type == "CREDIT" {
                    if classification.role == "income" {
                        income += amount
                    }
                    
                    continue
                }
                
                guard type == "DEBIT" else {
                    continue
                }
                
                totalDebitAmount += amount
                
                let confidenceForAmount: Double
                
                if classification.needsReview {
                    confidenceForAmount = min(Double(classification.confidence), 50)
                    reviewCount += 1
                } else {
                    confidenceForAmount = Double(classification.confidence)
                }
                
                confidenceWeightedSum += amount * confidenceForAmount
                
                if classification.confidence >= 75 && !classification.needsReview {
                    classifiedDebitAmount += amount
                }
                
                if classification.needsReview {
                    review += amount
                    continue
                }
                
                if isOutlier(item) {
                    outliers += amount
                    continue
                }
                
                switch classification.role {
                case "committed_outflow":
                    committed += amount
                    
                case "fund_building":
                    fund += amount
                    
                case "liability_payment":
                    liability += amount
                    
                case "cash_withdrawal":
                    review += amount
                    reviewCount += 1
                    
                case "everyday_spend":
                    everyday += amount
                    
                default:
                    review += amount
                    reviewCount += 1
                }
            }
            
            let remaining = income
            - committed
            - everyday
            - fund
            - liability
            - outliers
            - review
            
            let confidence = calculateConfidence(
                totalDebitAmount: totalDebitAmount,
                confidenceWeightedSum: confidenceWeightedSum
            )
            
            return MonthlySnapshot(
                id: "\(personaId.rawValue)_\(month)",
                personaId: personaId,
                month: month,
                income: income,
                committed: committed,
                everyday: everyday,
                fund: fund,
                liability: liability,
                outliers: outliers,
                review: review,
                remaining: remaining,
                totalDebits: totalDebitAmount,
                classifiedDebits: classifiedDebitAmount,
                confidence: confidence,
                transactionCount: items.count,
                reviewCount: reviewCount
            )
        }
        
        private func isOutlier(_ item: ClassifiedTransaction) -> Bool {
            let transaction = item.transaction
            let classification = item.classification
            
            guard transaction.type.uppercased() == "DEBIT" else {
                return false
            }
            
            if classification.role == "committed_outflow" ||
                classification.role == "fund_building" ||
                classification.role == "liability_payment" {
                return false
            }
            
            if transaction.amount >= 15_000 {
                return true
            }
            
            return false
        }
        
        private func calculateConfidence(
            totalDebitAmount: Double,
            confidenceWeightedSum: Double
        ) -> Int {
            guard totalDebitAmount > 0 else {
                return 100
            }
            
            let weightedAverage = confidenceWeightedSum / totalDebitAmount
            let percentage = Int(weightedAverage.rounded())
            
            return min(max(percentage, 0), 100)
        }
        
        private func monthKey(for transaction: RawTransaction) -> String? {
            if let valueDate = transaction.valueDate, valueDate.count >= 7 {
                return String(valueDate.prefix(7))
            }
            
            if let timestamp = transaction.timestamp, timestamp.count >= 7 {
                return String(timestamp.prefix(7))
            }
            
            return nil
        }
    }

