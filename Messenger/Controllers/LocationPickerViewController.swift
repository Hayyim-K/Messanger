//
//  LocationPickerViewController.swift
//  Messenger
//
//  Created by Hayyim on 25/01/2024.
//

import UIKit
//import CoreLocation
import MapKit

class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private var isPickable = true
    private let map = MKMapView()
    
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinates = coordinates
        self.isPickable = coordinates == nil
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setMap()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    private func setMap() {
        
        if isPickable {
            
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Send",
                style: .done,
                target: self,
                action: #selector(sendButtonTapped)
            )
            
            let center = CLLocationCoordinate2D(
                latitude: 31.776711,
                longitude: 35.234538
            )
            
            map.region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            map.isUserInteractionEnabled = true
            
            let gesture = UITapGestureRecognizer(
                target: self,
                action: #selector(didTapMap(_:))
            )
            //            gesture.numberOfTouchesRequired = 1
            //            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
            
        }
        else {
            guard let coordinates = coordinates
            else { return }
            
            map.region = MKCoordinateRegion(
                center: coordinates,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            // drop a pin on that location
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        view.addSubview(map)
    }
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates
        else { return }
        
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        
        // drop a pin on that location
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
}

