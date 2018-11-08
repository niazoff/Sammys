//
//  ConfirmationViewController.swift
//  Sammys
//
//  Created by Natanel Niazoff on 4/12/18.
//  Copyright © 2018 Natanel Niazoff. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

protocol ConfirmationViewControllerDelegate {
    func confirmationViewControllerDidDismiss(_ confirmationViewController: ConfirmationViewController)
}

class ConfirmationViewController: UIViewController, Storyboardable {
    typealias ViewController = ConfirmationViewController
    
    let viewModel = ConfirmationViewModel()
    var cellViewModels = [CollectionViewCellViewModel]() {
        didSet {
            collectionView.reloadData()
        }
    }
    var delegate: ConfirmationViewControllerDelegate?
    
    // MARK: - IBOutlets
    @IBOutlet var collectionView: UICollectionView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    struct Constants {
        static let cornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
        static let shadowOpacity: Float = 0.2
        static let sammysCoordinates = CLLocationCoordinate2D(latitude: 40.902340, longitude: -74.004410)
        static let sammys = "Sammy's"
        static let maps = "Maps"
        static let waze = "Waze"
        static let googleMaps = "Google Maps"
        static let wazeBaseURL = "waze://"
        static let googleMapsBaseURL = "comgooglemaps://"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Thank You!"
        cellViewModels = viewModel.cellViewModels(for: view.bounds)
    }
    
    func presentNavigationAlert() {
        let navigationAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        // Add Maps action.
        navigationAlertController.addAction(
            UIAlertAction(title: Constants.maps, style: .default) { action in
            Constants.sammysCoordinates.openInMaps()
            })
        // Add Google Maps action if user has downloaded.
        if URL.canOpen(Constants.googleMapsBaseURL) {
            navigationAlertController.addAction(
                UIAlertAction(title: Constants.googleMaps, style: .default) { action in
                    Constants.sammysCoordinates.openInGoogleMaps()
                })
        }
        // Add Waze action if user has downloaded.
        if URL.canOpen(Constants.wazeBaseURL) {
            navigationAlertController.addAction(
                UIAlertAction(title: Constants.wazeBaseURL, style: .default) { action in
                    Constants.sammysCoordinates.navigateInWaze()
                })
        }
        // Add cancel action.
        navigationAlertController.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { action in
            navigationAlertController.dismiss(animated: true, completion: nil)
            })
        present(navigationAlertController, animated: true, completion: nil)
    }
    
    func cellViewModel(at row: Int) -> CollectionViewCellViewModel? {
        guard !cellViewModels.isEmpty && row < cellViewModels.count else { return nil }
        return cellViewModels[row]
    }
    
    static func configureUI(for cell: UICollectionViewCell) {
        cell.contentView.layer.masksToBounds = true
        cell.contentView.layer.cornerRadius = Constants.cornerRadius
        cell.contentView.layer.borderWidth = Constants.borderWidth
        cell.contentView.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.masksToBounds = false
        cell.add(UIView.Shadow(path: UIBezierPath(roundedRect: cell.bounds, cornerRadius: cell.contentView.layer.cornerRadius).cgPath, opacity: Constants.shadowOpacity))
    }
    
    // MARK: - IBActions
    @IBAction func didTapDone(_ sender: UIBarButtonItem) {
        dismiss(animated: true) { self.delegate?.confirmationViewControllerDidDismiss(self) }
    }
}

extension ConfirmationViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.numberOfSections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cellViewModel = cellViewModel(at: indexPath.row)
            else { fatalError() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellViewModel.identifier, for: indexPath)
        cellViewModel.commands[.configuration]?.perform(parameters: CollectionViewCellCommandParameters(cell: cell))
        return cell
    }
}

extension ConfirmationViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {}
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let cellViewModel = cellViewModel(at: indexPath.row)
            else { fatalError() }
        //return cellViewModel.size
		return CGSize.zero
    }
}

private extension CLLocationCoordinate2D {
    func openInMaps() {
        let placemark = MKPlacemark(coordinate: self, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = ConfirmationViewController.Constants.sammys
        mapItem.openInMaps(launchOptions: nil)
    }
    
    func navigateInWaze() {
        guard URL.canOpen(ConfirmationViewController.Constants.wazeBaseURL) else { return }
        URL.open("\(ConfirmationViewController.Constants.wazeBaseURL)?ll=\(latitude),\(longitude)&navigate=yes")
    }
    
    func openInGoogleMaps() {
        guard URL.canOpen(ConfirmationViewController.Constants.googleMapsBaseURL) else { return }
        URL.open("\(ConfirmationViewController.Constants.googleMapsBaseURL)?q=\(latitude),\(longitude)")
    }
}
