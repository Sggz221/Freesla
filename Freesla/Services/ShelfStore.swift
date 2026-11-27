//
//  ShelfStore.swift
//  Freesla
//
//  Estante de archivos: guardas archivos soltándolos en la isla y los sacas arrastrándolos.
//  No copiamos los archivos, guardamos una referencia. Usamos "bookmarks" en lugar de rutas
//  porque siguen funcionando aunque el archivo se mueva o se renombre.
//

import Foundation

nonisolated struct ShelfItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
}

@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []

    private static let defaultsKey = "shelf.bookmarks"

    init() {
        load()
    }

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !items.contains(where: { $0.url == url }) {
            items.append(ShelfItem(url: url))
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        let bookmarks = items.compactMap { try? $0.url.bookmarkData() }
        UserDefaults.standard.set(bookmarks, forKey: Self.defaultsKey)
    }

    private func load() {
        let bookmarks = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [Data] ?? []
        items = bookmarks.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ShelfItem(url: url)
        }
    }
}
