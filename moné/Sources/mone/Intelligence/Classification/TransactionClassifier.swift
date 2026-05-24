import Foundation

final class TransactionClassifier {

    private let registry = KnownEntityRegistry()
    private let featureExtractor = TransactionFeatureExtractor()
    
    private func travelCategory(for text: String) -> String {
        if text.contains("INDIGO") ||
            text.contains("AIR INDIA") ||
            text.contains("AKASA") ||
            text.contains("VISTARA") ||
            text.contains("AIRLINES") {
            return "flight"
        }

        if text.contains("HOTEL") ||
            text.contains("MAKE MY TRIP") ||
            text.contains("MAKEMYTRIP") ||
            text.contains("GOIBIBO") ||
            text.contains("CLEARTRIP") ||
            text.contains("YATRA") {
            return "hotel_or_booking"
        }

        if text.contains("IRCTC") {
            return "train"
        }

        if text.contains("RED BUS") || text.contains("REDBUS") {
            return "bus"
        }

        return "travel"
    }
    
    private func broadResult(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        entityType: String,
        role: String,
        family: String,
        category: String,
        confidence: Int,
        evidence: String,
        needsReview: Bool,
        options: [String]
    ) -> ClassificationResult {
        ClassificationResult(
            transactionId: transaction.id,
            canonicalEntityName: parsed.normalizedCounterparty,
            entityType: entityType,
            role: role,
            categoryFamily: family,
            category: category,
            confidence: confidence,
            evidence: [evidence],
            needsReview: needsReview,
            reviewReason: needsReview ? "High-impact transaction in broad category" : nil,
            reviewOptions: options
        )
    }

    private func utilityCategory(for text: String) -> String {
        if text.contains("ELECTRICITY") || text.contains("BESCOM") {
            return "electricity"
        }

        if text.contains("FIBERNET") || text.contains("BROADBAND") {
            return "broadband"
        }

        if text.contains("MOBILE") {
            return "mobile_bill"
        }

        if text.contains("LPG") || text.contains("GAS") {
            return "lpg_gas"
        }

        if text.contains("WATER") || text.contains("RO SERVICE") {
            return "water_ro_service"
        }

        return "utilities"
    }

    private func foodCategory(for text: String) -> String {
        if text.contains("BREWERY") ||
            text.contains("PUB") ||
            text.contains("TOIT") ||
            text.contains("LIQUOR") ||
            text.contains("HOOKAH") {
            return "alcohol_nightlife"
        }

        if text.contains("BAKERY") || text.contains("CAKE") {
            return "bakery_sweets"
        }

        return "street_food_snacks"
    }

    private func groceryCategory(for text: String) -> String {
        if text.contains("DMART") {
            return "supermarket"
        }

        if text.contains("FRUIT") || text.contains("VEG") {
            return "fruits_vegetables"
        }

        if text.contains("MILK") {
            return "dairy"
        }

        return "local_grocery"
    }

    private func localServiceCategory(for text: String) -> String {
        if text.contains("XEROX") || text.contains("PRINT") || text.contains("STATIONERY") {
            return "printing_stationery"
        }

        if text.contains("PLUMBER") || text.contains("ELECTRICIAN") || text.contains("HARDWARE") {
            return "home_repair"
        }

        if text.contains("SALON") {
            return "salon_grooming"
        }

        if text.contains("COURIER") {
            return "courier"
        }

        return "local_service"
    }
    
    private func personalCareCategory(for text: String) -> String {
        if text.contains("SALON") || text.contains("SPA") {
            return "salon_grooming"
        }

        if text.contains("GYM") || text.contains("FITNESS") {
            return "fitness"
        }

        if text.contains("WELLNESS") {
            return "wellness"
        }

        return "other_personal_care"
    }
    
    private func lifestyleCategory(for text: String) -> String {
        if text.contains("PVR") || text.contains("INOX") || text.contains("MOVIE") {
            return "movies"
        }

        if text.contains("EVENT") || text.contains("BOOKMYSHOW") {
            return "events"
        }

        if text.contains("PLAYSTATION") || text.contains("GAME") {
            return "games"
        }

        return "other_lifestyle"
    }
    
    private func classifyFromBroadPatterns(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        features: TransactionFeatures
    ) -> ClassificationResult? {

        let text = parsed.normalizedCounterparty ?? ""
        
        if text.contains("INCOME TAX") ||
            text.contains("TAX PAYMENT") ||
            text.contains("TDS") ||
            text.contains("GST") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "tax_authority",
                role: "committed_outflow",
                family: "tax",
                category: "income_tax_payment",
                confidence: 94,
                evidence: "Tax payment keyword detected",
                needsReview: false,
                options: []
            )
        }
        
        if text.contains("INDIGO") ||
            text.contains("AIR INDIA") ||
            text.contains("AKASA") ||
            text.contains("VISTARA") ||
            text.contains("AIRLINES") ||
            text.contains("MAKE MY TRIP") ||
            text.contains("MAKEMYTRIP") ||
            text.contains("GOIBIBO") ||
            text.contains("CLEARTRIP") ||
            text.contains("YATRA") ||
            text.contains("HOTEL") ||
            text.contains("RED BUS") ||
            text.contains("REDBUS") ||
            text.contains("IRCTC") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "travel_merchant",
                role: "everyday_spend",
                family: "travel",
                category: travelCategory(for: text),
                confidence: 88,
                evidence: "Travel merchant keyword detected",
                needsReview: transaction.amount >= 75_000,
                options: [
                    "Flight",
                    "Hotel",
                    "Train",
                    "Bus",
                    "Vacation",
                    "Work travel",
                    "Other travel"
                ]
            )
        }
        
        if text.contains("BANK CHARGE") ||
            text.contains("LATE FEE") ||
            text.contains("PENALTY") ||
            text.contains("SERVICE CHARGE") ||
            text.contains("PLATFORM FEE") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "fee_or_charge",
                role: MoneRole.everydaySpend,
                family: MoneCategoryFamily.feesCharges,
                category: "fee_or_charge",
                confidence: 82,
                evidence: "Fee/charge keyword detected",
                needsReview: transaction.amount >= 5_000,
                options: ["Bank fee", "Late fee", "Penalty", "Platform fee", "Other fee"]
            )
        }
        
        if text.contains("PVR") ||
            text.contains("INOX") ||
            text.contains("MOVIE") ||
            text.contains("EVENT") ||
            text.contains("BOOKMYSHOW") ||
            text.contains("PLAYSTATION") ||
            text.contains("GAME") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "lifestyle_merchant",
                role: MoneRole.everydaySpend,
                family: MoneCategoryFamily.lifestyleEntertainment,
                category: lifestyleCategory(for: text),
                confidence: 82,
                evidence: "Lifestyle/entertainment keyword detected",
                needsReview: false,
                options: ["Movies", "Events", "Games", "Hobbies", "Other lifestyle"]
            )
        }
        
        if text.contains("COURSE") ||
            text.contains("EXAM FEE") ||
            text.contains("TUITION") ||
            text.contains("BOOK STORE") ||
            text.contains("BOOKS") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "education_merchant",
                role: MoneRole.everydaySpend,
                family: MoneCategoryFamily.education,
                category: "education_expense",
                confidence: 82,
                evidence: "Education keyword detected",
                needsReview: transaction.amount >= 20_000,
                options: ["Course", "Books", "Exam fee", "Tuition", "Other education"]
            )
        }
        
        if text.contains("SALON") ||
            text.contains("SPA") ||
            text.contains("GYM") ||
            text.contains("FITNESS") ||
            text.contains("WELLNESS") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "personal_care_merchant",
                role: MoneRole.everydaySpend,
                family: MoneCategoryFamily.personalCare,
                category: personalCareCategory(for: text),
                confidence: 82,
                evidence: "Personal care/wellness keyword detected",
                needsReview: false,
                options: ["Salon", "Gym", "Wellness", "Other personal care"]
            )
        }

        if text.contains("DIAGNOSTIC") ||
            text.contains("CLINIC") ||
            text.contains("HOSPITAL") ||
            text.contains("PHARMACY") ||
            text.contains("MEDICAL") ||
            text.contains("MEDICALS") ||
            text.contains("DOCTOR") ||
            text.contains("DR ") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "medical_provider",
                role: "everyday_spend",
                family: "medical",
                category: text.contains("DIAGNOSTIC") ? "diagnostics" : "medical",
                confidence: 86,
                evidence: "Medical/healthcare keyword detected",
                needsReview: transaction.amount >= 10_000,
                options: ["Medicine", "Doctor visit", "Diagnostic test", "Dental", "Family healthcare", "Other medical"]
            )
        }

        if text.contains("MAINTENANCE") ||
            text.contains("SOCIETY") ||
            text.contains("APARTMENT") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "housing_service",
                role: "committed_outflow",
                family: "housing",
                category: "society_maintenance",
                confidence: 88,
                evidence: "Housing maintenance keyword detected",
                needsReview: false,
                options: []
            )
        }

        if text.contains("BESCOM") ||
            text.contains("ELECTRICITY") ||
            text.contains("FIBERNET") ||
            text.contains("BROADBAND") ||
            text.contains("MOBILE") ||
            text.contains("LPG") ||
            text.contains("GAS") ||
            text.contains("WATER CAN") ||
            text.contains("RO SERVICE") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "utility_or_home_service",
                role: features.hasBillSignal || features.hasMonthMarker ? "committed_outflow" : "everyday_spend",
                family: "utilities",
                category: utilityCategory(for: text),
                confidence: 84,
                evidence: "Utility/home-service keyword detected",
                needsReview: false,
                options: []
            )
        }

        if text.contains("PAAN") ||
            text.contains("PAN SHOP") ||
            text.contains("CIGARETTE") ||
            text.contains("TOBACCO") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "local_merchant",
                role: "everyday_spend",
                family: "small_street_shop",
                category: "tobacco_paan",
                confidence: 90,
                evidence: "Paan/tobacco keyword detected",
                needsReview: false,
                options: ["Tobacco / paan", "Tea / snacks", "Street food", "Local grocery", "Other local shop"]
            )
        }

        if text.contains("BAKERY") ||
            text.contains("CAKE") ||
            text.contains("CHAAT") ||
            text.contains("MOMO") ||
            text.contains("JUICE") ||
            text.contains("BREWERY") ||
            text.contains("PUB") ||
            text.contains("TOIT") ||
            text.contains("LIQUOR") ||
            text.contains("HOOKAH") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "food_or_nightlife_merchant",
                role: "everyday_spend",
                family: "food_snacks",
                category: foodCategory(for: text),
                confidence: 84,
                evidence: "Food/snacks/nightlife keyword detected",
                needsReview: false,
                options: ["Food / snacks", "Alcohol / nightlife", "Street food", "Restaurant", "Other"]
            )
        }

        if text.contains("KIRANA") ||
            text.contains("DMART") ||
            text.contains("FRUIT") ||
            text.contains("VEG") ||
            text.contains("MILK") ||
            text.contains("STORES") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "grocery_merchant",
                role: "everyday_spend",
                family: "groceries",
                category: groceryCategory(for: text),
                confidence: 84,
                evidence: "Grocery/household keyword detected",
                needsReview: false,
                options: ["Groceries", "Fruits / vegetables", "Dairy", "Household item", "Other grocery"]
            )
        }

        if text.contains("AUTO") ||
            text.contains("METRO") ||
            text.contains("PARKING") ||
            text.contains("TYRE") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "transport_merchant",
                role: "everyday_spend",
                family: "transport",
                category: "local_transport",
                confidence: 80,
                evidence: "Transport keyword detected",
                needsReview: false,
                options: ["Auto / cab", "Metro", "Parking", "Vehicle maintenance", "Other transport"]
            )
        }

        if text.contains("XEROX") ||
            text.contains("PRINT") ||
            text.contains("STATIONERY") ||
            text.contains("PLUMBER") ||
            text.contains("ELECTRICIAN") ||
            text.contains("HARDWARE") ||
            text.contains("SALON") ||
            text.contains("COURIER") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "local_service",
                role: "everyday_spend",
                family: "local_service",
                category: localServiceCategory(for: text),
                confidence: 76,
                evidence: "Local service keyword detected",
                needsReview: transaction.amount >= 5_000,
                options: ["Home repair", "Printing / stationery", "Salon", "Courier", "Vehicle service", "Other local service"]
            )
        }

        if text.contains("FLOWER") ||
            text.contains("GIFT") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "local_merchant",
                role: "everyday_spend",
                family: "shopping",
                category: "gifts_flowers",
                confidence: 76,
                evidence: "Gift/flower keyword detected",
                needsReview: transaction.amount >= 5_000,
                options: ["Gift", "Flowers", "Personal shopping", "Event purchase", "Other"]
            )
        }

        if text.contains("TEMPLE") ||
            text.contains("DONATION") ||
            text.contains("PUJA") {

            return broadResult(
                transaction: transaction,
                parsed: parsed,
                entityType: "local_merchant",
                role: "everyday_spend",
                family: "other",
                category: "donation_religious",
                confidence: 78,
                evidence: "Donation/religious keyword detected",
                needsReview: false,
                options: ["Donation", "Religious purchase", "Gift", "Other"]
            )
        }

        return nil
    }
    
    private func investmentCategory(for text: String) -> String {
        if text.contains("NPS") {
            return "nps"
        }

        if text.contains("RECURRING DEPOSIT") {
            return "recurring_deposit"
        }

        if text.contains("SIP") {
            return "sip"
        }

        return "mutual_fund"
    }

    func classify(transaction: RawTransaction, parsed: ParsedNarration) -> ClassificationResult {
        let features = featureExtractor.extract(
            transaction: transaction,
            parsed: parsed
        )

        if let accountTypeResult = classifyFromAccountType(transaction: transaction, parsed: parsed) {
            return accountTypeResult
        }

        if let keywordResult = classifyFromHighConfidenceKeywords(
            transaction: transaction,
            parsed: parsed,
            features: features
        ) {
            return keywordResult
        }

        if let knownEntity = registry.match(normalizedCounterparty: parsed.normalizedCounterparty) {
            return classifyFromKnownEntity(
                transaction: transaction,
                parsed: parsed,
                entity: knownEntity,
                features: features
            )
        }

        if let broadPatternResult = classifyFromBroadPatterns(
            transaction: transaction,
            parsed: parsed,
            features: features
        ) {
            return broadPatternResult
        }

        return bucketFirstFallback(
            transaction: transaction,
            parsed: parsed,
            features: features
        )
    }

    private func classifyFromAccountType(
        transaction: RawTransaction,
        parsed: ParsedNarration
    ) -> ClassificationResult? {

        let accountType = transaction.accountType.lowercased()

        if accountType == "mutual_funds" {
            // Debits from MF accounts are redemptions — money flowing back, not new investment
            let isRedemption = transaction.type.uppercased() == "DEBIT"
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "investment_account",
                role: isRedemption ? "asset_transfer" : "fund_building",
                categoryFamily: "investments",
                category: "mutual_fund",
                confidence: 92,
                evidence: [isRedemption ? "MF redemption/debit treated as asset transfer" : "Source account type is mutual_funds"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if accountType == "recurring_deposit" {
            // Debits from RD accounts are premature/maturity closures — asset transfer, not fresh contribution
            let isClosure = transaction.type.uppercased() == "DEBIT"
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "deposit_account",
                role: isClosure ? "asset_transfer" : "fund_building",
                categoryFamily: "investments",
                category: "recurring_deposit",
                confidence: 92,
                evidence: [isClosure ? "RD closure/debit treated as asset transfer" : "Source account type is recurring_deposit"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if accountType == "term_deposit" {
            // Debits from TD accounts are maturity/premature closures — asset transfer, not fresh contribution
            let isClosure = transaction.type.uppercased() == "DEBIT"
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "deposit_account",
                role: isClosure ? "asset_transfer" : "fund_building",
                categoryFamily: "investments",
                category: "term_deposit",
                confidence: 92,
                evidence: [isClosure ? "TD closure/debit treated as asset transfer" : "Source account type is term_deposit"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if accountType == "insurance_policies" {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "insurance_account",
                role: "committed_outflow",
                categoryFamily: "insurance",
                category: "insurance_policy",
                confidence: 90,
                evidence: ["Source account type is insurance_policies"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        return nil
    }

    private func classifyFromHighConfidenceKeywords(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        features: TransactionFeatures
    ) -> ClassificationResult? {

        let text = parsed.normalizedCounterparty ?? parsed.rawNarration.uppercased()

        if text.contains("SELF ACCOUNT TRANSFER") ||
            text.contains("OWN ACCOUNT") ||
            text.contains("SAVINGS TRANSFER") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "self_account",
                role: "self_transfer",
                categoryFamily: "transfers",
                category: "self_transfer",
                confidence: 96,
                evidence: ["Detected self/own account transfer"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("CASH WITHDRAWAL") || transaction.mode.uppercased() == "ATM" {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "cash",
                role: "cash_withdrawal",
                categoryFamily: "cash",
                category: "cash_withdrawal",
                confidence: 96,
                evidence: ["ATM mode or cash withdrawal narration"],
                needsReview: transaction.amount >= 5_000,
                reviewReason: transaction.amount >= 5_000 ? "Material cash withdrawal needs allocation context" : nil,
                reviewOptions: [
                    "Groceries",
                    "Household help",
                    "Transport",
                    "Food / snacks",
                    "Medical",
                    "Cash reserve",
                    "Multiple categories",
                    "Other"
                ]
            )
        }

        // Househelp salary — check BEFORE generic SALARY so it doesn't misfire as income
        let househelpSignals = ["HOUSEHELP SALARY", "MAID SALARY", "COOK SALARY",
                                "BHAIYA SALARY", "DIDI SALARY", "DOMESTIC SALARY"]
        if househelpSignals.contains(where: { text.contains($0) }) {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "household_service",
                role: "committed_outflow",
                categoryFamily: "household_help",
                category: "household_help",
                confidence: 93,
                evidence: ["Counterparty contains househelp salary signal"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("SALARY") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "employer",
                role: "income",
                categoryFamily: "income",
                category: "salary",
                confidence: 98,
                evidence: ["Counterparty contains SALARY"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        // ── Digital subscriptions ────────────────────────────────────────────
        let subscriptionSignals: [(keyword: String, name: String)] = [
            ("NETFLIX", "Netflix"),
            ("SPOTIFY", "Spotify"),
            ("APPLE", "Apple"),
            ("ICLOUD", "iCloud"),
            ("YOUTUBE", "YouTube Premium"),
            ("GOOGLE ONE", "Google One"),
            ("HOTSTAR", "Disney+ Hotstar"),
            ("DISNEY", "Disney+ Hotstar"),
            ("AMAZON PRIME", "Amazon Prime"),
            ("PRIME VIDEO", "Amazon Prime"),
            ("PRIMEVIDEO", "Amazon Prime"),
            ("TRUECALLER", "Truecaller Premium"),
            ("LINKEDIN", "LinkedIn Premium"),
            ("ZEE5", "Zee5"),
            ("SONYLIV", "SonyLIV"),
            ("JIOCINEMA", "JioCinema"),
            ("LENSKART", "Lenskart"),
            ("CULT FIT", "Cult.fit"),
            ("CULTFIT", "Cult.fit"),
            ("CURE FIT", "Cult.fit"),
            ("HEADSPACE", "Headspace"),
            ("DUOLINGO", "Duolingo"),
            ("CANVA", "Canva"),
            ("ADOBE", "Adobe"),
            ("NOTION", "Notion"),
            ("DROPBOX", "Dropbox"),
            ("GITHUB", "GitHub"),
            ("MICROSOFT 365", "Microsoft 365"),
            ("OFFICE 365", "Microsoft 365"),
        ]
        for signal in subscriptionSignals {
            if text.contains(signal.keyword) {
                return ClassificationResult(
                    transactionId: transaction.id,
                    canonicalEntityName: signal.name,
                    entityType: "subscription_service",
                    role: "committed_outflow",
                    categoryFamily: "subscriptions",
                    category: "digital_subscription",
                    confidence: 92,
                    evidence: ["Counterparty matches known subscription service: \(signal.name)"],
                    needsReview: false,
                    reviewReason: nil,
                    reviewOptions: []
                )
            }
        }

        // Credit card bill payments — monthly committed obligation
        if text.contains("CREDIT CARD") || text.contains("CC PAYMENT") || text.contains("CC BILL") || text.contains("CARD PAYMENT") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "credit_card",
                role: "committed_outflow",
                categoryFamily: "credit_card",
                category: "credit_card_payment",
                confidence: 93,
                evidence: ["Counterparty contains credit card payment signal"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("RENT") || text.contains("LANDLORD") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "housing",
                role: "committed_outflow",
                categoryFamily: "housing",
                category: "rent",
                confidence: 96,
                evidence: ["Counterparty contains RENT or LANDLORD"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("LOAN") || text.contains("EMI") || text.contains("CREDILA") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "lender",
                role: "liability_payment",
                categoryFamily: "debt",
                category: text.contains("EDUCATION") ? "education_loan_emi" : "loan_emi",
                confidence: 94,
                evidence: ["Counterparty contains LOAN/EMI/CREDILA"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("SIP") ||
            text.contains("MUTUAL FUND") ||
            text.contains("BLUECHIP") ||
            text.contains("MIDCAP") ||
            text.contains("NPS") ||
            text.contains("RECURRING DEPOSIT") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "investment",
                role: "fund_building",
                categoryFamily: "investments",
                category: investmentCategory(for: text),
                confidence: 94,
                evidence: ["Counterparty contains investment/fund-building signal"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        if text.contains("HOUSEHELP") ||
            text.contains("DOMESTIC HELP") ||
            text.contains("COOK PAYMENT") ||
            text.contains("CAR CLEANER") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "household_service",
                role: features.hasMonthMarker || transaction.amount >= 2_000 ? "committed_outflow" : "everyday_spend",
                categoryFamily: "household_help",
                category: "household_help",
                confidence: 86,
                evidence: ["Counterparty contains household help/service signal"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        return nil
    }

    private func classifyFromKnownEntity(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        entity: KnownEntity,
        features: TransactionFeatures
    ) -> ClassificationResult {

        if entity.isPaymentProcessor {
            let shouldReview =
                transaction.amount >= 2_000 ||
                features.aiEligible

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: entity.canonicalName,
                entityType: entity.entityType,
                role: "everyday_spend",
                categoryFamily: "local_upi",
                category: "other_local_spend",
                confidence: entity.confidenceBase,
                evidence: [
                    "Matched payment processor \(entity.canonicalName)",
                    "Payment processor identifies rail, not exact merchant",
                    "Assigned broad local UPI bucket"
                ],
                needsReview: shouldReview,
                reviewReason: shouldReview ? "High-impact payment processor-only transaction" : nil,
                reviewOptions: [
                    "Tea / snacks",
                    "Paan / tobacco",
                    "Street food",
                    "Kirana / grocery",
                    "Local service",
                    "Friend / person transfer",
                    "Other local spend"
                ]
            )
        }

        return ClassificationResult(
            transactionId: transaction.id,
            canonicalEntityName: entity.canonicalName,
            entityType: entity.entityType,
            role: entity.role,
            categoryFamily: entity.categoryFamily,
            category: entity.category,
            confidence: entity.confidenceBase,
            evidence: [
                "Matched known entity \(entity.canonicalName)"
            ],
            needsReview: entity.confidenceBase < 65,
            reviewReason: entity.confidenceBase < 65 ? "Known entity match has low confidence" : nil,
            reviewOptions: []
        )
    }

    private func classifyFromLocalPatterns(
        transaction: RawTransaction,
        parsed: ParsedNarration
    ) -> ClassificationResult? {

        let text = parsed.normalizedCounterparty ?? ""

        if text.contains("BREWERY") ||
            text.contains("PUB") ||
            text.contains("TOIT") ||
            text.contains("LIQUOR") ||
            text.contains("WINE SHOP") ||
            text.contains("HOOKAH") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "food_snacks",
                category: "alcohol_nightlife",
                confidence: 86,
                evidence: ["Local merchant contains nightlife/alcohol token"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Alcohol / nightlife",
                    "Restaurant",
                    "Friend split",
                    "Celebration / event",
                    "Other"
                ]
            )
        }
        
        if text.contains("BAKERY") ||
            text.contains("CAKE SHOP") ||
            text.contains("CHAAT") ||
            text.contains("MOMO") ||
            text.contains("JUICE") ||
            text.contains("FOOD CORNER") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "food_snacks",
                category: "street_food_snacks",
                confidence: 86,
                evidence: ["Local merchant contains street food/snack token"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Street food",
                    "Tea / snacks",
                    "Bakery",
                    "Juice",
                    "Other"
                ]
            )
        }
        
        if text.contains("AUTO") ||
            text.contains("METRO CARD") ||
            text.contains("PARKING") ||
            text.contains("TYRE PUNCTURE") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "transport",
                category: "local_transport",
                confidence: 82,
                evidence: ["Local merchant contains transport-related token"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Auto / cab",
                    "Metro",
                    "Parking",
                    "Vehicle maintenance",
                    "Other transport"
                ]
            )
        }
        
        if text.contains("ELECTRICIAN") ||
            text.contains("PLUMBER") ||
            text.contains("HARDWARE") ||
            text.contains("CAR CLEANER") ||
            text.contains("COOK PAYMENT") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_service",
                role: "everyday_spend",
                categoryFamily: "local_upi",
                category: "local_service",
                confidence: 78,
                evidence: ["Local merchant contains service/home-repair token"],
                needsReview: transaction.amount > 3000,
                reviewReason: transaction.amount > 3000 ? "High-value local service transaction" : nil,
                reviewOptions: [
                    "Home repair",
                    "Household service",
                    "Cook / cleaner",
                    "Vehicle service",
                    "Other local service"
                ]
            )
        }
        
        if text.contains("FRUIT") ||
            text.contains("VEG") ||
            text.contains("NANDINI MILK") ||
            text.contains("MILK") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "groceries",
                category: "fruits_vegetables_dairy",
                confidence: 86,
                evidence: ["Local merchant contains fruit/vegetable/dairy token"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Fruits / vegetables",
                    "Dairy",
                    "Local grocery",
                    "Other"
                ]
            )
        }
        
        if text.contains("TEMPLE") ||
            text.contains("DONATION") ||
            text.contains("PUJA") {

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "personal",
                category: "donation_religious",
                confidence: 82,
                evidence: ["Local merchant contains donation/religious token"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Donation",
                    "Religious purchase",
                    "Gift",
                    "Other"
                ]
            )
        }
        
        
        
        if text.contains("PAAN") || text.contains("PAN SHOP") || text.contains("CIGARETTE") || text.contains("TOBACCO") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "small_street_shop",
                category: "tobacco_paan",
                confidence: 90,
                evidence: ["Local merchant contains PAAN/CIGARETTE/TOBACCO"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Tobacco / paan",
                    "Tea / snacks",
                    "Street food",
                    "Local grocery",
                    "Other local shop"
                ]
            )
        }

        if text.contains("TEA") || text.contains("CHAI") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "food_snacks",
                category: "tea_snacks",
                confidence: 86,
                evidence: ["Local merchant contains TEA or CHAI"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Tea / snacks",
                    "Street food",
                    "Paan / tobacco",
                    "Other"
                ]
            )
        }

        if text.contains("KIRANA") || text.contains("STORES") || text.contains("MART") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "groceries",
                category: "local_grocery",
                confidence: 82,
                evidence: ["Local merchant contains KIRANA/STORES/MART"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: [
                    "Local grocery",
                    "Household item",
                    "Tea / snacks",
                    "Other"
                ]
            )
        }

        if text.contains("PHARMACY") || text.contains("MEDICAL") || text.contains("MEDICALS") {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "local_merchant",
                role: "everyday_spend",
                categoryFamily: "medical",
                category: "pharmacy",
                confidence: 90,
                evidence: ["Local merchant contains PHARMACY/MEDICAL"],
                needsReview: false,
                reviewReason: nil,
                reviewOptions: []
            )
        }

        return nil
    }

    private func bucketFirstFallback(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        features: TransactionFeatures
    ) -> ClassificationResult {

        if transaction.type.uppercased() == "CREDIT" {
            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "unknown_credit",
                role: "unknown",
                categoryFamily: "income",
                category: "uncategorized_credit",
                confidence: 45,
                evidence: ["Credit transaction without deterministic income/refund/self-transfer evidence"],
                needsReview: true,
                reviewReason: "Credit transaction needs confirmation",
                reviewOptions: [
                    "Salary",
                    "Refund",
                    "Reimbursement",
                    "Investment redemption",
                    "Own account transfer",
                    "Other credit"
                ]
            )
        }

        if features.isPersonLikeCounterparty {
            let shouldReview = transaction.amount >= 10_000

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "person",
                role: "everyday_spend",
                categoryFamily: "transfers",
                category: "person_transfer",
                confidence: shouldReview ? 55 : 62,
                evidence: [
                    "Counterparty looks like a person name",
                    shouldReview ? "High-value person transfer should be reviewed" : "Low/medium value person transfer assigned broad transfer bucket"
                ],
                needsReview: shouldReview,
                reviewReason: shouldReview ? "High-value person transfer needs purpose confirmation" : nil,
                reviewOptions: [
                    "Family support",
                    "Friend split",
                    "Loan repayment",
                    "Rent / shared housing",
                    "Gift",
                    "Other transfer"
                ]
            )
        }

        if features.isPaymentProcessorOnly {
            let shouldReview = transaction.amount >= 2_000

            return ClassificationResult(
                transactionId: transaction.id,
                canonicalEntityName: parsed.normalizedCounterparty,
                entityType: "payment_processor_or_generic_qr",
                role: "everyday_spend",
                categoryFamily: "local_upi",
                category: "other_local_spend",
                confidence: shouldReview ? 45 : 52,
                evidence: [
                    "Payment processor-only narration",
                    "Assigned broad local UPI bucket"
                ],
                needsReview: shouldReview,
                reviewReason: shouldReview ? "High-value local UPI transaction needs confirmation" : nil,
                reviewOptions: [
                    "Tea / snacks",
                    "Paan / tobacco",
                    "Street food",
                    "Kirana / grocery",
                    "Local service",
                    "Friend / person transfer",
                    "Other local spend"
                ]
            )
        }

        let shouldReview = transaction.amount >= 10_000

        return ClassificationResult(
            transactionId: transaction.id,
            canonicalEntityName: parsed.normalizedCounterparty,
            entityType: "unknown",
            role: "everyday_spend",
            categoryFamily: "other",
            category: "other_everyday",
            confidence: shouldReview ? 45 : 58,
            evidence: [
                "No deterministic match",
                "Assigned broad other everyday bucket"
            ],
            needsReview: shouldReview,
            reviewReason: shouldReview ? "High-value unknown debit needs confirmation" : nil,
            reviewOptions: [
                "Food / snacks",
                "Groceries",
                "Transport",
                "Shopping",
                "Medical",
                "Transfer",
                "Other"
            ]
        )
    }
}
