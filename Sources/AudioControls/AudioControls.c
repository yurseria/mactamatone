#include "AudioControls.h"
#include <stdatomic.h>
#include <stdlib.h>

struct AudioControls {
    _Atomic double frequency;
    _Atomic double mouth;
    _Atomic int gate;
    _Atomic double outputLevel;
    _Atomic uint64_t outputSequence;
};

AudioControls *AudioControlsCreate(void) {
    AudioControls *controls = calloc(1, sizeof(AudioControls));
    if (controls) {
        atomic_store(&controls->frequency, 220.0);
        atomic_store(&controls->mouth, 0.5);
        atomic_store(&controls->gate, 0);
        atomic_store(&controls->outputLevel, 0);
        atomic_store(&controls->outputSequence, 0);
    }
    return controls;
}

void AudioControlsDestroy(AudioControls *controls) { free(controls); }
void AudioControlsSetFrequency(AudioControls *controls, double value) { atomic_store(&controls->frequency, value); }
void AudioControlsSetMouth(AudioControls *controls, double value) { atomic_store(&controls->mouth, value); }
void AudioControlsSetGate(AudioControls *controls, int value) { atomic_store(&controls->gate, value); }
double AudioControlsGetFrequency(const AudioControls *controls) { return atomic_load(&controls->frequency); }
double AudioControlsGetMouth(const AudioControls *controls) { return atomic_load(&controls->mouth); }
int AudioControlsGetGate(const AudioControls *controls) { return atomic_load(&controls->gate); }

void AudioControlsPublishOutputLevel(AudioControls *controls, double rms) {
    atomic_store_explicit(&controls->outputLevel, rms, memory_order_relaxed);
    atomic_fetch_add_explicit(&controls->outputSequence, 1, memory_order_release);
}
double AudioControlsGetOutputLevel(const AudioControls *controls) {
    return atomic_load_explicit(&controls->outputLevel, memory_order_relaxed);
}
uint64_t AudioControlsGetOutputSequence(const AudioControls *controls) {
    return atomic_load_explicit(&controls->outputSequence, memory_order_acquire);
}
