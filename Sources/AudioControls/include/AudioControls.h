#ifndef AUDIO_CONTROLS_H
#define AUDIO_CONTROLS_H

#include <stdint.h>

typedef struct AudioControls AudioControls;
AudioControls *AudioControlsCreate(void);
void AudioControlsDestroy(AudioControls *controls);
void AudioControlsSetFrequency(AudioControls *controls, double value);
void AudioControlsSetMouth(AudioControls *controls, double value);
void AudioControlsSetGate(AudioControls *controls, int value);
double AudioControlsGetFrequency(const AudioControls *controls);
double AudioControlsGetMouth(const AudioControls *controls);
int AudioControlsGetGate(const AudioControls *controls);

// One publication per audio buffer; the UI never runs on the audio thread.
void AudioControlsPublishOutputLevel(AudioControls *controls, double rms);
double AudioControlsGetOutputLevel(const AudioControls *controls);
uint64_t AudioControlsGetOutputSequence(const AudioControls *controls);

#endif
