//
//  WeatherService.swift
//  FireWorkSimulator
//
//  Created by copilot on 2025/01/11.
//

import Foundation
import CoreLocation

// MARK: - Weather Service for Temperature-based Sound Speed 🌡️
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentTemperature: Double = 20.0 // Default 20°C
    @Published var soundSpeed: Double = 343.0 // m/s at 20°C
    
    private let locationManager = CLLocationManager()
    private let temperatureUpdateInterval: TimeInterval = 600 // Update every 10 minutes
    private var lastUpdateTime: Date = Date.distantPast
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTemperatureTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("[WeatherService] Location services not enabled")
            return
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Check if we need to update (avoid too frequent API calls)
        guard Date().timeIntervalSince(lastUpdateTime) > temperatureUpdateInterval else {
            return
        }
        
        fetchWeatherData(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[WeatherService] Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startTemperatureTracking()
        }
    }
    
    private func fetchWeatherData(for location: CLLocation) {
        // Using OpenWeatherMap API for temperature
        // Note: In production, you'd want to secure the API key
        let apiKey = "demo_key" // Replace with actual API key
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("[WeatherService] API error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                DispatchQueue.main.async {
                    self.updateTemperature(weatherResponse.main.temp)
                }
            } catch {
                print("[WeatherService] JSON parsing error: \(error)")
                // Fallback: Use simulated temperature variation for demo
                DispatchQueue.main.async {
                    let simulatedTemp = Double.random(in: 15.0...25.0)
                    self.updateTemperature(simulatedTemp)
                }
            }
        }.resume()
        
        lastUpdateTime = Date()
    }
    
    private func updateTemperature(_ temperature: Double) {
        currentTemperature = temperature
        // Calculate sound speed: v = 331.3 * sqrt(1 + T/273.15)
        soundSpeed = 331.3 * sqrt(1 + temperature / 273.15)
        print("[WeatherService] Temperature: \(temperature)°C, Sound speed: \(soundSpeed) m/s")
    }
}

// MARK: - Weather API Response Models
struct WeatherResponse: Codable {
    let main: MainWeather
}

struct MainWeather: Codable {
    let temp: Double
}