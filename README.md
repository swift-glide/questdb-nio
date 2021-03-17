# QuestDB + SwiftNIO

A [QuestDB](https://questdb.io) REST client designed to work with server-side Swift applications with `Codable` support.

## Install (SPM)

Add the package to your dependencies in `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/swift-glide/questdb-nio.git", .from("0.1.0"))
]
```

## Usage

Start by creating a client instance:

```swift
let client = QuestDBClient()
```

When no configuration is passed, the client will look for the `QUESTDB_URL` environment variable and use it if available. Otherwise, it will default to `http://localhost:9000`.

You can pass a configuration object as well as an NIO HTTP client during initialization:

```swift
let client = QuestDBClient(
  config: QuestDBConfig(url: "http://localhost:9000"),
  httpClient: HTTPClient(
    eventLoopGroupProvider: .createNew
  )
)
```

Once you have a client, you can call the `execute` instance method to execute your queries:

```swift
client.execute(
  options: ExecuteOptions(
    query: """
    CREATE TABLE readings(
        db_ts timestamp,
        device_ts timestamp,
        device_name symbol,
        reading int)
    timestamp(db_ts);
    """
  )
)
```

If you want the query to execute on a specific event loop, you can pass it as an argument as well:

```swift
client.execute(
  on: someEventLoop, 
  options: ...
)
```

This method returns an event loop future wrapping a `Codable` type.

If the return type can't be inferred from the call site, you can specify it as follows:

```swift
client.execute(
  on: someEventLoop, 
  options: ...,
  returning: SomeDecodableType.self
)
```

Many requests return a `QuestOperationResponse` object, so use it accordingly.

You can further customize your request using the `ExecuteOptions` type, including `count`, `limit`, `nm`, and `timings`. Please refer to the [official QuestDB docs](https://questdb.io/docs/reference/api/rest#exec---execute-queries) for more information.

## Supported Endpoints

- [x] `/exec`
- [ ] `/imp`
- [ ] `/exp`

## Vapor + QuestDB

If you plan to use this package with a Vapor 4 app, here are some snippets to get you started. We first create a service type inside `Application`:

```swift
import Vapor
import QuestDB

extension Application {
  struct QuestDB {
    let app: Application

    struct Key: StorageKey {
      typealias Value = QuestDBClient
    }

    var client: QuestDBClient {
      get {
        guard let client = self.app.storage[Key.self] else {
          fatalError("QuestDBClient is not setup. Use application.quest.client to set it up.")
        }

        return client
      }

      nonmutating set {
        self.app.storage.set(Key.self, to: newValue) {
          try $0.syncShutdown()
        }
      }
    }
  }

  var quest: QuestDB {
    .init(app: self)
  }

  var questClient: QuestDBClient {
    quest.client
  }
}
```

Then we do the same with `Request`:

```swift
extension Request {
  struct QuestDB {
    var client: QuestDBClient {
      return request.application.quest.client
    }

    let request: Request
  }

  var quest: QuestDB { .init(request: self) }

  var questClient: QuestDBClient {
    quest.client
  }
}
```

When configuring your `app` instance:

```swift
let client = QuestDBClient(httpClient: app.http.client.shared)
app.quest.client = client
```

For operations that you do frequently, you can extend the client to keep things DRY:

```swift
extension QuestDBClient {
  func createTable(
    on eventLoop: EventLoop? = nil
  ) -> Future<QuestOperationResponse> {
    execute(
      on: eventLoop,
      options: .init(
        query: """
        ...
        """
      )
    )
  }
```

## Project Status & Contributions

The package handles all the use cases that it was initially designed for. That being said, PRs are very welcome, especially if they tackle some of the following:

- Adding missing endpoints.
- Adding a test suite.

## License

See LICENSE.
