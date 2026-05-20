import Foundation

final class KnownEntityRegistry {

    private let entities: [KnownEntity] = [

        // MARK: - Food delivery / snacks

        KnownEntity(
            canonicalName: "Swiggy",
            aliases: ["SWIGGY", "SWIGGY INSTAMART"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "food_delivery",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Toit",
            aliases: ["TOIT"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "alcohol_nightlife",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Zomato",
            aliases: ["ZOMATO", "ZOMATO GOLD"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "food_delivery",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Blinkit",
            aliases: ["BLINKIT"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "groceries",
            category: "quick_commerce",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Zepto",
            aliases: ["ZEPTO"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "groceries",
            category: "quick_commerce",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Third Wave Coffee",
            aliases: ["THIRD WAVE COFFEE"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "coffee",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Starbucks",
            aliases: ["STARBUCKS"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "coffee",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Dominos",
            aliases: ["DOMINOS", "DOMINO'S"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "food_snacks",
            category: "restaurant_fast_food",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        // MARK: - Transport

        KnownEntity(
            canonicalName: "Uber",
            aliases: ["UBER"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "transport",
            category: "cab",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Ola",
            aliases: ["OLA"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "transport",
            category: "cab",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Rapido",
            aliases: ["RAPIDO"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "transport",
            category: "bike_taxi",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        // MARK: - Shopping

        KnownEntity(
            canonicalName: "Nike",
            aliases: ["NIKE", "NIKE INDIA"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "apparel",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Amazon",
            aliases: ["AMAZON", "AMZN"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "ecommerce",
            confidenceBase: 88,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "DMart",
            aliases: ["DMART", "D MART"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "groceries",
            category: "supermarket",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Amazon Prime",
            aliases: ["AMAZON PRIME", "PRIME MEMBERSHIP"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Flipkart",
            aliases: ["FLIPKART"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "ecommerce",
            confidenceBase: 88,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Myntra",
            aliases: ["MYNTRA"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "fashion",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Croma",
            aliases: ["CROMA"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "electronics",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Zara",
            aliases: ["ZARA"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "shopping",
            category: "fashion",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        // MARK: - Subscriptions / software

        KnownEntity(
            canonicalName: "Netflix",
            aliases: ["NETFLIX"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "entertainment_subscription",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "OpenAI",
            aliases: ["OPENAI", "CHATGPT"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "software_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Adobe",
            aliases: ["ADOBE"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "software_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Figma",
            aliases: ["FIGMA"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "software_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Truecaller",
            aliases: ["TRUECALLER", "TRUECALLER PREMIUM"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "utility_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "LinkedIn Premium",
            aliases: ["LINKEDIN PREMIUM"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "professional_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Newspaper Digital",
            aliases: ["NEWSPAPER DIGITAL"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "news_subscription",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Metro Card",
            aliases: ["METRO CARD"],
            entityType: "transport",
            role: "everyday_spend",
            categoryFamily: "transport",
            category: "public_transport",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Spotify",
            aliases: ["SPOTIFY"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "music_subscription",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "iCloud",
            aliases: ["ICLOUD", "APPLE ICLOUD"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "cloud_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "YouTube Premium",
            aliases: ["YOUTUBE PREMIUM"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "entertainment_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Google One",
            aliases: ["GOOGLE ONE"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "subscriptions",
            category: "cloud_subscription",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        // MARK: - Utilities

        KnownEntity(
            canonicalName: "ACT Fibernet",
            aliases: ["ACT FIBERNET", "ACT BROADBAND"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "utilities",
            category: "broadband",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),
        
        KnownEntity(
            canonicalName: "Indane LPG",
            aliases: ["INDANE LPG", "LPG", "GAS"],
            entityType: "utility_biller",
            role: "committed_outflow",
            categoryFamily: "utilities",
            category: "lpg_gas",
            confidenceBase: 90,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Airtel",
            aliases: ["AIRTEL"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "utilities",
            category: "mobile_or_broadband",
            confidenceBase: 88,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Jio",
            aliases: ["JIO"],
            entityType: "known_brand",
            role: "committed_outflow",
            categoryFamily: "utilities",
            category: "mobile_or_broadband",
            confidenceBase: 88,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "BESCOM",
            aliases: ["BESCOM", "ELECTRICITY BILL"],
            entityType: "utility_biller",
            role: "committed_outflow",
            categoryFamily: "utilities",
            category: "electricity",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),

        // MARK: - Debt / EMI

        KnownEntity(
            canonicalName: "HDFC Credila",
            aliases: ["HDFC CREDILA", "CREDILA"],
            entityType: "lender",
            role: "liability_payment",
            categoryFamily: "debt",
            category: "education_loan_emi",
            confidenceBase: 98,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Bajaj Finance",
            aliases: ["BAJAJ FINANCE", "BAJAJ FINSERV"],
            entityType: "lender",
            role: "liability_payment",
            categoryFamily: "debt",
            category: "emi",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),

        // MARK: - Investments

        KnownEntity(
            canonicalName: "HDFC Mutual Fund",
            aliases: ["HDFC BLUECHIP FUND", "HDFC MUTUAL FUND"],
            entityType: "fund_house",
            role: "fund_building",
            categoryFamily: "investments",
            category: "mutual_fund",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Axis Mutual Fund",
            aliases: ["AXIS MIDCAP FUND", "AXIS MUTUAL FUND"],
            entityType: "fund_house",
            role: "fund_building",
            categoryFamily: "investments",
            category: "mutual_fund",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "ICICI Prudential Mutual Fund",
            aliases: ["ICICI PRUDENTIAL BLUECHIP", "ICICI PRUDENTIAL MUTUAL FUND"],
            entityType: "fund_house",
            role: "fund_building",
            categoryFamily: "investments",
            category: "mutual_fund",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "NPS",
            aliases: ["NPS TIER I", "NPS TIER II", "NPS"],
            entityType: "retirement_investment",
            role: "fund_building",
            categoryFamily: "investments",
            category: "nps",
            confidenceBase: 96,
            isPaymentProcessor: false
        ),

        // MARK: - Insurance

        KnownEntity(
            canonicalName: "HDFC Ergo",
            aliases: ["HDFC ERGO"],
            entityType: "insurer",
            role: "committed_outflow",
            categoryFamily: "insurance",
            category: "insurance_premium",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Max Life",
            aliases: ["MAX LIFE"],
            entityType: "insurer",
            role: "committed_outflow",
            categoryFamily: "insurance",
            category: "life_insurance_premium",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),

        // MARK: - Healthcare

        KnownEntity(
            canonicalName: "Apollo Pharmacy",
            aliases: ["APOLLO PHARMACY"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "medical",
            category: "pharmacy",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "Tata 1mg",
            aliases: ["TATA 1MG", "1MG"],
            entityType: "known_brand",
            role: "everyday_spend",
            categoryFamily: "medical",
            category: "pharmacy",
            confidenceBase: 95,
            isPaymentProcessor: false
        ),
        
        // MARK: - OTHER

        KnownEntity(
            canonicalName: "Indigo Airlines",
            aliases: ["INDIGO", "INDIGO AIRLINES"],
            entityType: "known_brand",
            role: MoneRole.everydaySpend,
            categoryFamily: MoneCategoryFamily.travel,
            category: "flight",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "MakeMyTrip",
            aliases: ["MAKE MY TRIP", "MAKEMYTRIP", "MMT"],
            entityType: "known_brand",
            role: MoneRole.everydaySpend,
            categoryFamily: MoneCategoryFamily.travel,
            category: "hotel_or_booking",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "IRCTC",
            aliases: ["IRCTC"],
            entityType: "known_brand",
            role: MoneRole.everydaySpend,
            categoryFamily: MoneCategoryFamily.travel,
            category: "train",
            confidenceBase: 94,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "BookMyShow",
            aliases: ["BOOKMYSHOW", "BOOK MY SHOW"],
            entityType: "known_brand",
            role: MoneRole.everydaySpend,
            categoryFamily: MoneCategoryFamily.lifestyleEntertainment,
            category: "events",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        KnownEntity(
            canonicalName: "PVR INOX",
            aliases: ["PVR", "INOX", "PVR INOX"],
            entityType: "known_brand",
            role: MoneRole.everydaySpend,
            categoryFamily: MoneCategoryFamily.lifestyleEntertainment,
            category: "movies",
            confidenceBase: 92,
            isPaymentProcessor: false
        ),

        // MARK: - Payment processors

        KnownEntity(
            canonicalName: "Paytm QR",
            aliases: ["PAYTMQR", "PAYTM QR"],
            entityType: "payment_processor",
            role: "everyday_spend",
            categoryFamily: "local_upi",
            category: "unknown_local_upi",
            confidenceBase: 45,
            isPaymentProcessor: true
        ),

        KnownEntity(
            canonicalName: "PhonePe QR",
            aliases: ["PHONEPEQR", "PHONEPE QR"],
            entityType: "payment_processor",
            role: "everyday_spend",
            categoryFamily: "local_upi",
            category: "unknown_local_upi",
            confidenceBase: 45,
            isPaymentProcessor: true
        ),

        KnownEntity(
            canonicalName: "BharatPe",
            aliases: ["BHARATPE"],
            entityType: "payment_processor",
            role: "everyday_spend",
            categoryFamily: "local_upi",
            category: "unknown_local_upi",
            confidenceBase: 45,
            isPaymentProcessor: true
        ),

        KnownEntity(
            canonicalName: "Razorpay",
            aliases: ["RAZORPAY"],
            entityType: "payment_processor",
            role: "unknown",
            categoryFamily: "unknown",
            category: "payment_gateway",
            confidenceBase: 40,
            isPaymentProcessor: true
        )
    ]

    func match(normalizedCounterparty: String?) -> KnownEntity? {
        guard let normalizedCounterparty else {
            return nil
        }

        let upper = normalizedCounterparty.uppercased()

        let matches = entities.filter { entity in
            entity.aliases.contains { alias in
                upper.contains(alias.uppercased())
            }
        }

        return matches
            .sorted { first, second in
                let firstMaxAliasLength = first.aliases.map(\.count).max() ?? 0
                let secondMaxAliasLength = second.aliases.map(\.count).max() ?? 0
                return firstMaxAliasLength > secondMaxAliasLength
            }
            .first
    }
}
