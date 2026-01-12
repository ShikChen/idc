import ArgumentParser
import Foundation

struct InfoResponse: Decodable {
    let udid: String?
}

func fetchJSON<T: Decodable>(path: String, timeout: TimeInterval) async throws -> T {
    do {
        let data = try await fetchData(path: path, timeout: timeout)
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw ValidationError("Unable to reach idc-server. Run `idc server start`. (\(error.localizedDescription))")
    }
}

func fetchData(path: String, timeout: TimeInterval) async throws -> Data {
    let url = URL(string: "http://127.0.0.1:8080\(path)")!
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout

    return try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let data else {
                continuation.resume(throwing: URLError(.badServerResponse))
                return
            }
            continuation.resume(returning: data)
        }
        task.resume()
    }
}

func postJSON<T: Encodable>(path: String, body: T, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
    let url = URL(string: "http://127.0.0.1:8080\(path)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(body)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    } catch {
        throw ValidationError("Unable to reach idc-server. Run `idc server start`. (\(error.localizedDescription))")
    }
}
