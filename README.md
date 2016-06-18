# iPAFine
iOS IPA package refine and resign

1. Refine App Name based on file name.
2. Inject dylib into executable (so you can hook and modify the third party app at runtime).
3. Resign the app to ipa. Support application identity entitlements that required in 8.1.3.

Support 32/64 and Universal (FAT_MAGIC and FAT_CIGAM from [pebble](https://github.com/crazypebble/iPAFine/commit/14583fad7b773a393d9136eb3c8db4cacb544ee2)) binary

For testing only
