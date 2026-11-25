# xinPOS Diagnostic Logging

xinPOS writes diagnostic logs to the app's private documents directory:

`<application documents directory>/xinpos_logs/xinpos.log`

The logger keeps the current log plus up to three rotated files. Each log file is limited to approximately 1 MB. Older logs rotate automatically.

## Captured errors

- Flutter framework errors
- Uncaught platform errors
- Uncaught asynchronous errors
- Automatic database backup failures
- Errors explicitly recorded by application services

## Viewing and exporting

Open **Settings → Diagnostic Logs** to refresh, select/copy, export, or clear logs. Exported logs are plain text and can be attached to a support or development conversation.

Clearing diagnostic logs does not affect the xinPOS SQLite database, products, sales, or backups.

## Important limitation

Logging improves diagnosis; it does not guarantee that an error cannot crash or corrupt an operation. Critical database operations still need transactions, validation, migrations, and tests. Never use logs as a replacement for database backups.

Logs may contain exception messages and stack traces. Review the exported file before sharing it publicly.
