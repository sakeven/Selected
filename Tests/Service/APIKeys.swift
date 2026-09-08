import Foundation
import Testing
@testable import Selected

struct APIKeyStoreTests {
    @Test func migratesAllLegacyProvidersWithoutChangingValues() throws {
        let fixture = CredentialFixture()
        for provider in APIKeyStore.Provider.allCases {
            fixture.defaults.set("fixture-\(provider.rawValue)", forKey: provider.rawValue)
        }
        try fixture.store.migrateLegacyValues()
        for provider in APIKeyStore.Provider.allCases {
            #expect(fixture.store.value(for: provider) == "fixture-\(provider.rawValue)")
            #expect(fixture.defaults.object(forKey: provider.rawValue) == nil)
        }
        let writes = fixture.storage.writes
        try fixture.store.migrateLegacyValues()
        #expect(fixture.storage.writes == writes)
    }

    @Test func migrationPreservesTheAlreadySavedKeychainValue() throws {
        let fixture = CredentialFixture()
        fixture.defaults.set("legacy", forKey: APIKeyStore.Provider.openAI.rawValue)
        fixture.storage.values[APIKeyStore.Provider.openAI.rawValue] = "saved"
        try fixture.store.migrateLegacyValues()
        #expect(fixture.store.value(for: .openAI) == "saved")
        #expect(fixture.defaults.object(forKey: APIKeyStore.Provider.openAI.rawValue) == nil)
        #expect(fixture.storage.writes == 0)
    }

    @Test(arguments: [StorageOperation.read, .write])
    func failedMigrationRetainsTheUsableLegacyCredential(_ operation: StorageOperation) throws {
        let fixture = CredentialFixture()
        fixture.defaults.set("legacy", forKey: APIKeyStore.Provider.openAI.rawValue)
        fixture.storage.failure = operation
        #expect(throws: StorageFailure.unavailable) { try fixture.store.migrateLegacyValues() }
        #expect(fixture.defaults.string(forKey: APIKeyStore.Provider.openAI.rawValue) == "legacy")
        #expect(fixture.store.value(for: .openAI) == "legacy")
        fixture.storage.failure = nil
        try fixture.store.migrateLegacyValues()
        #expect(fixture.store.value(for: .openAI) == "legacy")
        #expect(fixture.defaults.object(forKey: APIKeyStore.Provider.openAI.rawValue) == nil)
    }

    @Test func editingAndClearingUseOnlySecureStorage() throws {
        let fixture = CredentialFixture()
        fixture.defaults.set("legacy", forKey: APIKeyStore.Provider.claude.rawValue)
        try fixture.store.save("new", for: .claude)
        #expect(fixture.store.value(for: .claude) == "new")
        #expect(fixture.defaults.object(forKey: APIKeyStore.Provider.claude.rawValue) == nil)
        try fixture.store.save("", for: .claude)
        #expect(fixture.storage.values.isEmpty)
        #expect(fixture.store.value(for: .claude).isEmpty)
    }

    @Test(arguments: [StorageOperation.write, .remove])
    func failedSaveDoesNotDiscardExistingCredentials(_ operation: StorageOperation) throws {
        let fixture = CredentialFixture()
        fixture.defaults.set("legacy", forKey: APIKeyStore.Provider.openAI.rawValue)
        fixture.storage.values[APIKeyStore.Provider.openAI.rawValue] = "saved"
        fixture.storage.failure = operation
        #expect(throws: StorageFailure.unavailable) {
            try fixture.store.save(operation == .remove ? "" : "new", for: .openAI)
        }
        #expect(fixture.store.value(for: .openAI) == "saved")
        #expect(fixture.defaults.string(forKey: APIKeyStore.Provider.openAI.rawValue) == "legacy")
    }

    @Test(arguments: [AppRuntimeMode.tests, .preview])
    func testingAndPreviewNeverAccessStoredCredentials(_ runtime: AppRuntimeMode) throws {
        let fixture = CredentialFixture()
        fixture.defaults.set("legacy", forKey: APIKeyStore.Provider.openAI.rawValue)
        let store = APIKeyStore(storage: fixture.storage, defaults: fixture.defaults, runtime: runtime)
        #expect(store.value(for: .openAI).isEmpty)
        try store.migrateLegacyValues()
        try store.save("new", for: .openAI)
        #expect(fixture.storage.operations == 0)
        #expect(fixture.defaults.string(forKey: APIKeyStore.Provider.openAI.rawValue) == "legacy")
    }
}

enum StorageOperation { case read, write, remove }
private enum StorageFailure: Error { case unavailable }

private final class MemorySecrets: SecretStorage {
    var values: [String: String] = [:]
    var failure: StorageOperation?
    var operations = 0
    var writes = 0

    func read(account: String) throws -> String? {
        operations += 1
        if failure == .read { throw StorageFailure.unavailable }
        return values[account]
    }
    func write(_ value: String, account: String) throws {
        operations += 1
        if failure == .write { throw StorageFailure.unavailable }
        values[account] = value
        writes += 1
    }
    func remove(account: String) throws {
        operations += 1
        if failure == .remove { throw StorageFailure.unavailable }
        values.removeValue(forKey: account)
    }
}

private final class CredentialFixture {
    let name = "SelectedTests.Credentials.\(UUID())"
    let defaults: UserDefaults
    let storage = MemorySecrets()
    var store: APIKeyStore { APIKeyStore(storage: storage, defaults: defaults, runtime: .normal) }

    init() { defaults = UserDefaults(suiteName: name)! }
    deinit { defaults.removePersistentDomain(forName: name) }
}
