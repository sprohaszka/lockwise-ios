## Building new Views

<img style="float: left;" src="storyboard_l10n.png" width="200">

Many of the layouts in Lockwise are constructed using `Storyboard`s. In order to support localizing these storyboard files, make sure that the actual `xml` for the layout lives in the `Base.lproj` directory, and language-based directories such as `en.lproj` contain only `.strings` files. This can be confirmed in Interface Builder by looking at the `Identity` tab in the right toolbar, and confirming that the Localization section specifies `Localizable Strings` for each language as shown in the image.

## Shared Business Logic between Lockwise + CredentialProvider

There are many `View`s, `Presenter`s, and `Store`s with code useful in both the Lockwise application and the CredentialProvider app extension. In service to iOS' restriction that apps and their extension run in separate processes ([extension documentation here](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html)), the following code sharing strategy minimizes the amount of code required in each to keep binary sizes small and performance snappy.

### Strategy

We have three directories at the top level of the project -- `lockbox-ios`, `CredentialProvider`, and `Shared`. Each of those directories is broken down into the same set of folders. All classes in the `Shared` directory are included in both the `Lockwise` and `CredentialProvider` targets; the other directories' code is included only in their respective targets.

### Inheritance

For classes that are used in both the `CredentialProvider` and `Lockwise`, the shared code lives in a `Base` implementation for the class (e.g. `BaseDataStore`, `BaseAccountStore`). Each target then implements its own version of the `Base` class, with `Lockwise.app` filenames simply removing the `Base` (e.g. `DataStore`, `AccountStore`) and `CredentialProvider.appextension` filenames prepending `Credential` (e.g. `CredentialDataStore`, `CredentialAccountStore`).

### Technical debt

The `Base` sharing strategy is clunky and can be confusing when interacting with code that spans a `Base-` class and its target-specific implementation. Future work might see this strategy move to the [recommended `.framework`](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW1) method for code sharing.
