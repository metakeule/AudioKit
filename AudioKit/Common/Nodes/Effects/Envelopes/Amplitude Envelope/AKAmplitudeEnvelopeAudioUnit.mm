//
//  AKAmplitudeEnvelopeAudioUnit.mm
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright (c) 2016 Aurelius Prochazka. All rights reserved.
//

#import "AKAmplitudeEnvelopeAudioUnit.h"
#import "AKAmplitudeEnvelopeDSPKernel.hpp"

#import <AVFoundation/AVFoundation.h>
#import "BufferedAudioBus.hpp"

#import <AudioKit/AudioKit-Swift.h>

@implementation AKAmplitudeEnvelopeAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    AKAmplitudeEnvelopeDSPKernel _kernel;

    BufferedInputBus _inputBus;
}
@synthesize parameterTree = _parameterTree;

- (void)setAttackDuration:(float)attackDuration {
    _kernel.setAttackDuration(attackDuration);
}
- (void)setDecayDuration:(float)decayDuration {
    _kernel.setDecayDuration(decayDuration);
}
- (void)setSustainLevel:(float)sustainLevel {
    _kernel.setSustainLevel(sustainLevel);
}
- (void)setReleaseDuration:(float)releaseDuration {
    _kernel.setReleaseDuration(releaseDuration);
}


- (void)start {
    _kernel.start();
}

- (void)stop {
    _kernel.stop();
}

- (BOOL)isPlaying {
    return _kernel.started;
}

- (BOOL)isSetUp {
    return _kernel.resetted;
}

- (void)createParameters {

    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:AKSettings.sampleRate
                                                                                  channels:AKSettings.numberOfChannels];

    // Create a DSP kernel to handle the signal processing.
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);

    // Create a parameter object for the attackDuration.
    AUParameter *attackDurationAUParameter =
    [AUParameterTree createParameterWithIdentifier:@"attackDuration"
                                              name:@"Attack time"
                                           address:attackDurationAddress
                                               min:0
                                               max:99
                                              unit:kAudioUnitParameterUnit_Seconds
                                          unitName:nil
                                             flags:0
                                      valueStrings:nil
                               dependentParameters:nil];
    // Create a parameter object for the decayDuration.
    AUParameter *decayDurationAUParameter =
    [AUParameterTree createParameterWithIdentifier:@"decayDuration"
                                              name:@"Decay time"
                                           address:decayDurationAddress
                                               min:0
                                               max:99
                                              unit:kAudioUnitParameterUnit_Seconds
                                          unitName:nil
                                             flags:0
                                      valueStrings:nil
                               dependentParameters:nil];
    // Create a parameter object for the sustainLevel.
    AUParameter *sustainLevelAUParameter =
    [AUParameterTree createParameterWithIdentifier:@"sustainLevel"
                                              name:@"Sustain Level"
                                           address:sustainLevelAddress
                                               min:0
                                               max:99
                                              unit:kAudioUnitParameterUnit_Generic
                                          unitName:nil
                                             flags:0
                                      valueStrings:nil
                               dependentParameters:nil];
    // Create a parameter object for the releaseDuration.
    AUParameter *releaseDurationAUParameter =
    [AUParameterTree createParameterWithIdentifier:@"releaseDuration"
                                              name:@"Release time"
                                           address:releaseDurationAddress
                                               min:0
                                               max:99
                                              unit:kAudioUnitParameterUnit_Seconds
                                          unitName:nil
                                             flags:0
                                      valueStrings:nil
                               dependentParameters:nil];


    // Initialize the parameter values.
    attackDurationAUParameter.value = 0.1;
    decayDurationAUParameter.value = 0.1;
    sustainLevelAUParameter.value = 1.0;
    releaseDurationAUParameter.value = 0.1;

    self.rampTime = AKSettings.rampTime;

    _kernel.setParameter(attackDurationAddress,  attackDurationAUParameter.value);
    _kernel.setParameter(decayDurationAddress,   decayDurationAUParameter.value);
    _kernel.setParameter(sustainLevelAddress,    sustainLevelAUParameter.value);
    _kernel.setParameter(releaseDurationAddress, releaseDurationAUParameter.value);

    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[
        attackDurationAUParameter,
        decayDurationAUParameter,
        sustainLevelAUParameter,
        releaseDurationAUParameter
    ]];

    // Make a local pointer to the kernel to avoid capturing self.
    __block AKAmplitudeEnvelopeDSPKernel *envelopeKernel = &_kernel;

    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        envelopeKernel->setParameter(param.address, value);
    };

    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        return envelopeKernel->getParameter(param.address);
    };

    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;

        switch (param.address) {
            case attackDurationAddress:
                return [NSString stringWithFormat:@"%.3f", value];

            case decayDurationAddress:
                return [NSString stringWithFormat:@"%.3f", value];

            case sustainLevelAddress:
                return [NSString stringWithFormat:@"%.3f", value];

            case releaseDurationAddress:
                return [NSString stringWithFormat:@"%.3f", value];

            default:
                return @"?";
        }
    };
    
    _inputBus.init(defaultFormat, 8);
    self.inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                                 busType:AUAudioUnitBusTypeInput
                                                                  busses:@[_inputBus.bus]];
}

#pragma mark - AUAudioUnit Overrides

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:kAudioUnitErr_FailedInitialization
                                        userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;

        return NO;
    }
    _inputBus.allocateRenderResources(self.maximumFramesToRender);

    _kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
    _kernel.reset();

    [self setUpParameterRamp];

    return YES;
}

- (void)deallocateRenderResources {
    [super deallocateRenderResources];
    _kernel.destroy();

    _inputBus.deallocateRenderResources();
}

- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block AKAmplitudeEnvelopeDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = &_inputBus;

    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        AudioUnitRenderActionFlags pullFlags = 0;

        AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);

        if (err != 0) {
            return err;
        }

        AudioBufferList *inAudioBufferList = input->mutableAudioBufferList;

        /*
         If the caller passed non-nil output pointers, use those. Otherwise,
         process in-place in the input buffer. If your algorithm cannot process
         in-place, then you will need to preallocate an output buffer and use
         it here.
         */
        AudioBufferList *outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }

        state->setBuffers(inAudioBufferList, outAudioBufferList);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);

        return noErr;
    };
}


@end


