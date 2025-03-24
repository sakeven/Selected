//
//  LocationManager.swift
//  Selected
//
//  Created by sake on 2024/7/3.
//

import Foundation
import CoreLocation


class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()


    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()


    var location: CLLocation?
    var place: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.location = location
        }
        var p : String? = nil
        geocoder.reverseGeocodeLocation(location) {
            placemarks, error in
            if let err = error {
                print("reverseGeocodeLocation \(err)")
                return
            } else if let placemarks = placemarks {
                if let placemark = placemarks.first {
                    p = "\(placemark.name!), \(placemark.locality!), \(placemark.administrativeArea!), \(placemark.country!)"
                    DispatchQueue.main.async {
                        self.place = p
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
}
