//
//  MultiDelay.swift
//  AnalogSynthX
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2016 AudioKit. All rights reserved.
//

import AudioKit

class MultiDelay: AKNode {

    let leftDelayMix = AKMixer()
    let rightDelayMix = AKMixer()
    var delayPannedLeft: AKPanner!
    var delayPannedRight: AKPanner!
    var mixer: AKMixer!

    var time: Double = 0.0 {
        didSet {
            leftTimes = [1, 2, 3].map { t -> Double in t * time }
            updateDelays(leftDelays, boosters: leftBoosters, times: leftTimes, gains: gains)

            rightTimes = [1.5, 2.5, 3.5].map { t -> Double in t * time }
            updateDelays(rightDelays, boosters: rightBoosters, times: rightTimes, gains: gains)
        }
    }

    var mix: Double = 0 {
        didSet {
            gains = [0.5, 0.25, 0.15].map { g -> Double in g * mix }
            updateDelays(leftDelays, boosters: leftBoosters, times: leftTimes, gains: gains)
            updateDelays(rightDelays, boosters: rightBoosters, times: rightTimes, gains: gains)
        }
    }

    fileprivate var leftDelays: [AKDelay] = []
    fileprivate var rightDelays: [AKDelay] = []
    fileprivate var leftBoosters: [AKBooster] = []
    fileprivate var rightBoosters: [AKBooster] = []
    fileprivate var gains = [0.5, 0.25, 0.15]
    fileprivate var leftTimes = [1.0, 2.0, 3.0]
    fileprivate var rightTimes = [1.5, 2.5, 3.5]

    func updateDelays(_ delays: [AKDelay], boosters: [AKBooster], times: [Double], gains: [Double]) {
        for i in 0..<gains.count {
            delays[i].time = times[i]
            boosters[i].gain = gains[i]
        }
    }

    init(_ input: AKNode) {

        for i in 0..<gains.count {
            leftDelays.append(AKDelay(input, time: leftTimes[i], feedback: 0.0))
            rightDelays.append(AKDelay(input, time: rightTimes[i], feedback: 0.0))
            leftBoosters.append(AKBooster(leftDelays[i], gain: gains[i]))
            rightBoosters.append(AKBooster(rightDelays[i], gain: gains[i]))

            leftDelayMix.connect(leftBoosters[i])
            rightDelayMix.connect(rightBoosters[i])
        }

        let delayPannedLeft = AKPanner(leftDelayMix, pan: -1)
        let delayPannedRight = AKPanner(rightDelayMix, pan: 1)

        mixer = AKMixer(delayPannedLeft, delayPannedRight)

        super.init()
        self.avAudioNode = mixer.avAudioNode
        input.addConnectionPoint(self)

    }
}
