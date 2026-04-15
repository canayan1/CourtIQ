import Foundation

enum BundleContentLoader {
    static func loadArray<T: Decodable>(_ type: [T].Type, named name: String, bundle: Bundle = .main) -> [T] {
        load(type, named: name, bundle: bundle) ?? []
    }

    static func load<T: Decodable>(_ type: T.Type, named name: String, bundle: Bundle = .main) -> T? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }
}
