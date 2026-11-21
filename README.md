# xinPOS

**xinPOS** is an offline-first point-of-sale (POS) application for Android, built with Flutter. The project is currently **under active development**. Its goal is to provide a practical and reliable POS system for a small business, with local data access and synchronization across multiple devices.

> [!WARNING]
> **Work in progress:** xinPOS is not yet a finished or production-ready application. Features, architecture, and workflows may change as development continues. Some items described below are planned and may not be implemented yet.

## Project Goals

- Provide a simple, user-friendly POS experience on Android phones and tablets.
- Support sales and inventory workflows for a single business.
- Work offline and keep essential POS operations available without an internet connection.
- Synchronize data with a central backend when a connection is available.
- Allow multiple devices to work with shared business and inventory data.
- Support cash and GCash payments initially.

## Planned Technology Stack

| Area | Technology |
| --- | --- |
| Mobile application | Flutter / Dart |
| State management | Riverpod |
| Navigation | GoRouter |
| Local database | SQLite with Drift |
| Backend API | Laravel REST API |
| Central database | MySQL |

The application is being designed around **Clean Architecture** and a **feature-first** project structure. The mobile app will use a local database as its primary data source, with backend synchronization for shared data and backups.

## Planned Features

The following list represents the project direction, not a claim that every feature is already available.

- [ ] Product and inventory management
- [ ] Sales and checkout
- [ ] Cash and GCash payment recording
- [ ] Receipt generation
- [ ] Offline transaction handling
- [ ] Synchronization between multiple devices
- [ ] Centralized business data through the Laravel API
- [ ] Sales history and basic reports
- [ ] Barcode scanning
- [ ] Receipt printing

Barcode scanning and receipt printing are optional capabilities and may be introduced in later development milestones.

## Architecture Overview

The planned system has two main parts:

1. **Flutter Android application** — handles the POS interface, business workflows, and local data storage using SQLite/Drift.
2. **Laravel backend** — provides the REST API and central MySQL database used to synchronize data between devices.

The mobile application is designed to remain usable offline. When connectivity returns, it can synchronize local changes with the backend. Synchronization rules and conflict handling will be refined during implementation.

## Development Status

xinPOS is an ongoing personal development project. Development is being done incrementally, with architecture, core workflows, and individual features implemented and tested through milestones.

There is currently no stable production release. Please treat the repository as a work in progress rather than a ready-to-deploy POS solution.

## Getting Started

The setup instructions will be added and updated as the application and backend development progress.

For now, make sure you have the Flutter SDK installed and configured:

- [Flutter installation guide](https://docs.flutter.dev/get-started/install)
- [Flutter documentation](https://docs.flutter.dev/)

## Contributing

The project is currently under active development, and its structure and implementation may change. Suggestions and bug reports are welcome through GitHub Issues.

## License

No license has been specified yet. All rights are reserved by the repository owner unless a license is added to this repository.
