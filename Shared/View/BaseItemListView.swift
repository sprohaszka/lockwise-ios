/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

typealias ItemSectionModel = AnimatableSectionModel<Int, LoginListCellConfiguration>

enum LoginListCellConfiguration {
    case Item(title: String, username: String, guid: String, highlight: Bool)
    case SyncListPlaceholder
    case EmptyListPlaceholder(learnMoreObserver: AnyObserver<Void>?)
    case NoResults
    case SelectAPasswordHelpText
    case NoNetwork(retryObserver: AnyObserver<Void>)
}

extension LoginListCellConfiguration: IdentifiableType {
    var identity: String {
        switch self {
        case .Item(_, _, let guid, _):
            return guid
        case .SyncListPlaceholder:
            return "syncplaceholder"
        case .EmptyListPlaceholder:
            return "emptyplaceholder"
        case .NoResults:
            return "noresultsplaceholder"
        case .SelectAPasswordHelpText:
            return "selectapasswordhelptext"
        case .NoNetwork:
            return "nonetwork"
        }
    }
}

extension LoginListCellConfiguration: Equatable {
    static func ==(lhs: LoginListCellConfiguration, rhs: LoginListCellConfiguration) -> Bool {
        switch (lhs, rhs) {
        case (.Item(let lhTitle, let lhUsername, _, let lhHighlight), .Item(let rhTitle, let rhUsername, _, let rhHighlight)):
            return lhTitle == rhTitle && lhUsername == rhUsername && lhHighlight == rhHighlight
        case (.SyncListPlaceholder, .SyncListPlaceholder): return true
        case (.EmptyListPlaceholder, .EmptyListPlaceholder): return true
        case (.NoResults, .NoResults): return true
        case (.NoNetwork, .NoNetwork): return true
        default:
            return false
        }
    }
}

class BaseItemListView: UIViewController {
    internal var basePresenter: BaseItemListPresenter?
    @IBOutlet weak var tableView: UITableView!
    internal var disposeBag = DisposeBag()
    private(set) var dataSource: RxTableViewSectionedAnimatedDataSource<ItemSectionModel>?

    var searchController: UISearchController?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.basePresenter = self.createPresenter()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Constant.color.viewBackground
        setNeedsStatusBarAppearanceUpdate()
        setupTableView()
        styleNavigationBar()
        setupDataSource()
        setupDelegate()
    }

    internal func createPresenter() -> BaseItemListPresenter {
        fatalError("Unimplemented")
    }

    internal func styleNavigationBar() {
        navigationItem.title = Constant.string.productName
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.accessibilityIdentifier = "firefoxLockwise.navigationBar"
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.navigationTitleFont
        ]
        
        searchController = self.getStyledSearchController()

        extendedLayoutIncludesOpaqueBars = true // Fixes tapping the status bar from showing partial pull-to-refresh
        navigationController?.iosThirteenNavBarAppearance()
    }

    func getStyledSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = self.shouldHidesNavigationBarDuringPresentation()
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.isActive = true
        searchController.searchBar.backgroundColor = Constant.color.navBackgroundColor
        searchController.searchBar.tintColor = UIColor.white // Cancel button
        searchController.searchBar.barStyle = .black // White text color

        searchController.searchBar.sizeToFit()

        searchController.searchBar.searchBarStyle = UISearchBar.Style.minimal

        searchController.searchBar.barTintColor = UIColor.clear // Constant.color.navSearchBackgroundColor

        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.definesPresentationContext = true

        let searchIcon = UIImage(named: "search-icon")?.withRenderingMode(.alwaysTemplate).tinted(Constant.color.navSearchPlaceholderTextColor)
        searchController.searchBar.setImage(searchIcon, for: UISearchBar.Icon.search, state: .normal)
        searchController.searchBar.setImage(UIImage(named: "clear-icon"), for: UISearchBar.Icon.clear, state: .normal)

        searchController.searchBar.setSearchFieldBackgroundImage(UIImage.color(UIColor.clear, size:  CGSize(width: 50, height: 38)), for: .normal) // Clear the background image
        searchController.searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 5.0, vertical: 0) // calling setSearchFieldBackgroundImage removes the spacing between the search icon and text
        if let searchField = searchController.searchBar.value(forKey: "searchField") as? UITextField {

            if let backgroundview = searchField.subviews.first {
                backgroundview.backgroundColor = Constant.color.inactiveNavSearchBackgroundColor
                backgroundview.layer.cornerRadius = 10
                backgroundview.clipsToBounds = true
            }
        }

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = UIColor.white // Set cursor color
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).attributedPlaceholder = NSAttributedString(string: Constant.string.searchYourEntries, attributes: [NSAttributedString.Key.foregroundColor: Constant.color.navSearchPlaceholderTextColor]) // Set the placeholder text and color

        return searchController
    }

    func shouldHidesNavigationBarDuringPresentation() -> Bool {
        return true
    }
}

extension BaseItemListView: BaseItemListViewProtocol {
    var sortingButtonHidden: AnyObserver<Bool>? {
        return (self.navigationItem.leftBarButtonItem?.customView as? UIButton)?.rx.isHidden.asObserver()
    }

    func bind(items: Driver<[ItemSectionModel]>) {
        if let dataSource = self.dataSource {
            items.drive(self.tableView.rx.items(dataSource: dataSource)).disposed(by: self.disposeBag)
        }
    }

    func dismissKeyboard() {
        if let searchBar = self.searchController?.searchBar {
            searchBar.resignFirstResponder()
        }
    }

    func bind(titleText: Driver<String>) {
        titleText
            .drive(self.navigationItem.rx.title)
            .disposed(by: self.disposeBag)
    }

    func setFilterEnabled(enabled: Bool) {
        DispatchQueue.main.async {
            self.searchController?.searchBar.isUserInteractionEnabled = enabled
        }
    }
}

extension BaseItemListView {
    fileprivate func setupDataSource() {
        self.dataSource = RxTableViewSectionedAnimatedDataSource<ItemSectionModel>(
                configureCell: { dataSource, tableView, path, _ in
                    let cellConfiguration = dataSource[path]

                    var retCell: UITableViewCell
                    switch cellConfiguration {
                    case .Item(let title, let username, _, let highlight):
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "itemlistcell") as? ItemListCell else {
                            fatalError("couldn't find the right cell!")
                        }

                        cell.titleLabel.text = title
                        cell.detailLabel.text = username

                        let view = UIView()
                        view.backgroundColor = Constant.color.tableViewCellHighlighted
                        cell.backgroundView = highlight ? view : nil

                        if (self.extensionContext == nil) {
                            cell.accessoryType = .disclosureIndicator
                        }

                        retCell = cell
                    case .SyncListPlaceholder:
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "itemlistplaceholder") else {
                            fatalError("couldn't find the right cell!")
                        }

                        retCell = cell
                    case .EmptyListPlaceholder(let learnMoreObserver):
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "emptylistplaceholder") as? EmptyPlaceholderCell else { // swiftlint:disable:this line_length
                            fatalError("couldn't find the right cell!")
                        }

                        cell.titleLabel.text = String(format: Constant.string.emptyListPlaceholder, Constant.string.productName)

                        if let observer = learnMoreObserver {
                            cell.learnMoreButton.rx.tap
                                    .bind(to: observer)
                                    .disposed(by: cell.disposeBag)
                        } else {
                            cell.learnMoreButton.isHidden = true
                        }
                        retCell = cell
                    case .NoResults:
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "noresultsplaceholder") as? NoResultsCell else {
                            fatalError("couldn't find the no results cell")
                        }

                        retCell = cell
                    case .SelectAPasswordHelpText:
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "selectapasswordhelptext") else {
                            fatalError("couldn't find the selectapassword cell")
                        }

                        let borderView = UIView()
                        borderView.frame = CGRect(x: 0, y: cell.frame.height-1, width: cell.frame.width, height: 1)
                        borderView.backgroundColor = Constant.color.helpTextBorderColor
                        cell.addSubview(borderView)

                        retCell = cell
                    case .NoNetwork(let retryObserver):
                        guard let cell = tableView.dequeueReusableCell(withIdentifier: "nonetwork") as? NoNetworkCell else {
                            fatalError("couldn't find the nonetwork cell")
                        }

                        cell.retryButton.rx.tap
                            .bind(to: retryObserver)
                            .disposed(by: cell.disposeBag)
                        
                        retCell = cell
                    }

                    return retCell
        })

        self.dataSource?.animationConfiguration = AnimationConfiguration(
                insertAnimation: .fade,
                reloadAnimation: .none,
                deleteAnimation: .fade
        )
    }

    fileprivate func setupDelegate() {
        if let presenter = self.basePresenter {

            if let searchController = self.searchController {
                searchController.searchBar.rx.text
                    .orEmpty
                    .asObservable()
                    .bind(to: presenter.filterTextObserver)
                    .disposed(by: self.disposeBag)

                searchController.searchBar.rx.cancelButtonClicked
                    .asObservable()
                    .bind(to: presenter.cancelObserver)
                    .disposed(by: self.disposeBag)
            }

            self.tableView.rx.itemSelected
                    .map { (path: IndexPath) -> String? in
                        self.tableView.deselectRow(at: path, animated: false)
                        guard let config = self.dataSource?[path] else {
                            return nil
                        }

                        switch config {
                        case .Item(_, _, let id, _):
                            return id
                        default:
                            return nil
                        }
                    }
                    .bind(to: presenter.itemSelectedObserver)
                    .disposed(by: self.disposeBag)
        }
    }
}

// view styling
extension BaseItemListView {
    fileprivate func setupTableView() {
        let backgroundView = UIView(frame: self.view.bounds)
        backgroundView.backgroundColor = Constant.color.viewBackground
        tableView.backgroundView = backgroundView
        tableView.keyboardDismissMode = .onDrag
    }
}

extension BaseItemListView: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        if let searchField = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            if let backgroundview = searchField.subviews.first {
                backgroundview.backgroundColor = Constant.color.activeNavSearchBackgroundColor
            }
        }
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        if let searchField = searchController.searchBar.value(forKey: "searchField") as? UITextField {

            if let backgroundview = searchField.subviews.first {
                backgroundview.backgroundColor = Constant.color.inactiveNavSearchBackgroundColor
            }
        }
    }
}

extension BaseItemListView: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {

    }
}
