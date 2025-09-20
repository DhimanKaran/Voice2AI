//
//  WhisperWrapper.mm.swift
//  PersonalConversationalBot
//
//  Created by karan dhiman on 20/09/2025.
//

#import "Voice2AIBridge.h"
#import <Foundation/Foundation.h>
#include <string>
#include "whisper.h"
#include <fstream>
#include <vector>

// 1. WAV loader
bool read_wav(const char * fname, std::vector<float> & pcmf32, int & sample_rate) {
    pcmf32.clear();
    sample_rate = 0;

    std::ifstream file(fname, std::ios::binary);
    if (!file) return false;

    char header[44];
    file.read(header, 44);

    int16_t num_channels = *reinterpret_cast<int16_t*>(&header[22]);
    sample_rate = *reinterpret_cast<int32_t*>(&header[24]);
    int16_t bits_per_sample = *reinterpret_cast<int16_t*>(&header[34]);
    int32_t data_size = *reinterpret_cast<int32_t*>(&header[40]);

    if (num_channels != 1 || bits_per_sample != 16) {
        return false;
    }

    std::vector<int16_t> pcm16(data_size / 2);
    file.read(reinterpret_cast<char*>(pcm16.data()), data_size);

    pcmf32.resize(pcm16.size());
    for (size_t i = 0; i < pcm16.size(); ++i) {
        pcmf32[i] = pcm16[i] / 32768.0f;
    }

    return true;
}

/// Transcribes 16-bit mono PCM raw buffer (16kHz, little-endian)
extern "C" const char* transcribe_from_wav(const char* modelPath, const int16_t* buffer, int num_samples) {
//extern "C" const char* transcribe_from_raw(const char* modelPath, const int16_t* buffer, int num_samples) {
    static std::string result;

    whisper_context* ctx = whisper_init_from_file(modelPath);
    if (!ctx) return "Failed to load model";

    std::vector<float> pcmf32(num_samples);
    for (int i = 0; i < num_samples; ++i) {
        pcmf32[i] = buffer[i] / 32768.0f;
    }

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.language = "en";
    params.print_progress = false;
    params.print_realtime = false;

    if (whisper_full(ctx, params, pcmf32.data(), pcmf32.size()) != 0) {
        whisper_free(ctx);
        return "Failed to transcribe";
    }

    result.clear();
    int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        result += whisper_full_get_segment_text(ctx, i);
        result += " ";
    }

    whisper_free(ctx);
    return result.c_str();
}
