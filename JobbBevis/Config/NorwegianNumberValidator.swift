import Foundation

enum NorwegianNumberValidator {
    static func organizationNumberDigits(from value: String) -> String? {
        let digits = normalizedDigits(from: value)
        guard digits.count == 9 else { return nil }
        let weights = [3, 2, 7, 6, 5, 4, 3, 2]
        return hasValidModulus11CheckDigit(digits, weights: weights) ? digits : nil
    }

    static func bankAccountDigits(from value: String) -> String? {
        let digits = normalizedDigits(from: value)
        guard digits.count == 11 else { return nil }
        let weights = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
        return hasValidModulus11CheckDigit(digits, weights: weights) ? digits : nil
    }

    static func formattedBankAccount(_ digits: String) -> String {
        guard digits.count == 11 else { return digits }
        let firstEnd = digits.index(digits.startIndex, offsetBy: 4)
        let secondEnd = digits.index(firstEnd, offsetBy: 2)
        return "\(digits[..<firstEnd]).\(digits[firstEnd..<secondEnd]).\(digits[secondEnd...])"
    }

    private static func normalizedDigits(from value: String) -> String {
        value.filter(\.isNumber)
    }

    private static func hasValidModulus11CheckDigit(_ digits: String, weights: [Int]) -> Bool {
        let numbers = digits.compactMap(\.wholeNumberValue)
        guard numbers.count == weights.count + 1 else { return false }
        let sum = zip(numbers.dropLast(), weights).reduce(0) { $0 + $1.0 * $1.1 }
        let calculated = 11 - (sum % 11)
        let checkDigit = calculated == 11 ? 0 : calculated
        return checkDigit != 10 && checkDigit == numbers.last
    }
}
