import Foundation

struct MovieMatch: Identifiable, Hashable {
    let id: Int
    let title: String
    let year: String
    let posterPath: String?
    let backdropPath: String?
    let overview: String
    var posterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") } }
}

/// Posters and runtimes. Optional: with no key, tickets show their own photo.
enum TMDb {
    static func search(_ title: String, year: String? = nil, key: String?) async -> [MovieMatch] {
        guard let key, var c = URLComponents(string: "https://api.themoviedb.org/3/search/movie") else { return [] }
        c.queryItems = [URLQueryItem(name: "api_key", value: key), URLQueryItem(name: "query", value: title)]
        if let year, !year.isEmpty { c.queryItems?.append(URLQueryItem(name: "year", value: year)) }
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = j["results"] as? [[String: Any]] else { return [] }
        return results.prefix(15).compactMap { r in
            guard let id = r["id"] as? Int else { return nil }
            return MovieMatch(id: id, title: r["title"] as? String ?? "", year: String((r["release_date"] as? String ?? "").prefix(4)),
                              posterPath: r["poster_path"] as? String, backdropPath: r["backdrop_path"] as? String, overview: r["overview"] as? String ?? "")
        }
    }

    static func runtime(_ id: Int, key: String?) async -> Int? {
        guard let key, let url = URL(string: "https://api.themoviedb.org/3/movie/\(id)?api_key=\(key)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (j["runtime"] as? Int).flatMap { $0 > 0 ? $0 : nil }
    }
}
