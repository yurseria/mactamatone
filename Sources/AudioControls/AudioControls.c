#include "AudioControls.h"
#include <stdatomic.h>
#include <stdlib.h>

struct AudioControls {
    _Atomic double frequency;
    _Atomic double mouth;
    _Atomic int gate;
};

AudioControls *AudioControlsCreate(void) {
    AudioControls *controls = calloc(1, sizeof(AudioControls));
    if (controls) {
        atomic_store(&controls->frequency, 220.0);
        atomic_store(&controls->mouth, 0.5);
        atomic_store(&controls->gate, 0);
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
