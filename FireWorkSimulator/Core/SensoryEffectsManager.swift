//
//  SensoryEffectsManager.swift
//  FireWorkSimulator
//
//  Created by copilot on 2025/01/11.
//

import AVFoundation
import UIKit
import simd

// MARK: - Sensory Effects Manager for Gen Z Experience 🎆
class SensoryEffectsManager: ObservableObject {
    
    // Audio engine for sound effects
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    private var explosionSoundBuffer: AVAudioPCMBuffer?
    
    // Haptic feedback generators
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    
    // Sound speed for realistic physics
    var soundSpeed: Double = 343.0 // m/s, updated from WeatherService
    
    init() {
        setupAudioEngine()
        prepareSounds()
    }
    
    private func setupAudioEngine() {
        // Attach the player node to the audio engine
        audioEngine.attach(audioPlayerNode)
        
        // Connect the player node to the output
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Start the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("[SensoryEffects] Failed to start audio engine: \(error)")
        }
    }
    
    private func prepareSounds() {
        // Generate explosion sound effect programmatically for that crisp Gen Z sound ✨
        generateExplosionSound()
        
        // Prepare haptic generators
        lightHaptic.prepare()
        mediumHaptic.prepare()
        heavyHaptic.prepare()
    }
    
    private func generateExplosionSound() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        
        let frameCount = AVAudioFrameCount(44100 * 0.5) // 0.5 second duration
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        // Generate explosion-like sound with noise burst and decay
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(format.sampleRate)
            
            // Create explosion sound: noise burst with exponential decay
            let noise = Float.random(in: -1.0...1.0)
            let decay = exp(-time * 8.0) // Quick decay
            let lowFreq = sin(2.0 * Float.pi * 60.0 * time) * 0.3 // Low frequency rumble
            
            channelData[i] = (noise * 0.7 + lowFreq) * decay * 0.8
        }
        
        explosionSoundBuffer = buffer
    }
    
    // MARK: - Public Methods for Distance-based Effects
    
    func triggerExplosionEffects(at explosionPosition: SIMD3<Float>, cameraPosition: SIMD3<Float>) {
        let distance = length(explosionPosition - cameraPosition)
        
        // Calculate realistic sound delay based on distance and sound speed
        let soundDelay = TimeInterval(distance / Float(soundSpeed))
        
        // Immediate haptic feedback based on distance
        triggerDistanceBasedHaptic(distance: distance)
        
        // Delayed sound effect for realism
        DispatchQueue.main.asyncAfter(deadline: .now() + soundDelay) { [weak self] in
            self?.playExplosionSound(distance: distance)
        }
        
        print("[SensoryEffects] Explosion at distance: \(distance)m, sound delay: \(soundDelay)s")
    }
    
    private func triggerDistanceBasedHaptic(distance: Float) {
        // Calculate haptic intensity based on distance (inverse square law with limits)
        let maxDistance: Float = 50.0
        let minDistance: Float = 1.0
        
        let clampedDistance = max(minDistance, min(maxDistance, distance))
        let intensity = 1.0 / (clampedDistance * clampedDistance / (minDistance * minDistance))
        let normalizedIntensity = max(0.1, min(1.0, intensity))
        
        // Choose haptic type based on intensity for that Gen Z feel 📳
        if normalizedIntensity > 0.7 {
            // Close explosion - heavy haptic
            heavyHaptic.impactOccurred(intensity: 1.0)
            
            // Add multiple pulses for dramatic effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.mediumHaptic.impactOccurred(intensity: 0.8)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.lightHaptic.impactOccurred(intensity: 0.6)
            }
            
        } else if normalizedIntensity > 0.4 {
            // Medium distance - medium haptic
            mediumHaptic.impactOccurred(intensity: normalizedIntensity)
            
        } else if normalizedIntensity > 0.2 {
            // Far distance - light haptic
            lightHaptic.impactOccurred(intensity: normalizedIntensity)
        }
        // Very far explosions have no haptic feedback
    }
    
    private func playExplosionSound(distance: Float) {
        guard let buffer = explosionSoundBuffer else { return }
        
        // Calculate volume based on distance (inverse square law)
        let maxDistance: Float = 100.0
        let minDistance: Float = 1.0
        
        let clampedDistance = max(minDistance, min(maxDistance, distance))
        let volume = 1.0 / (clampedDistance / minDistance)
        let normalizedVolume = max(0.05, min(1.0, volume))
        
        // Set up audio player with distance-based volume
        audioPlayerNode.volume = normalizedVolume
        
        // Schedule and play the sound
        audioPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        
        if !audioPlayerNode.isPlaying {
            audioPlayerNode.play()
        }
    }
    
    func updateSoundSpeed(_ newSoundSpeed: Double) {
        soundSpeed = newSoundSpeed
    }
}