# Voice2AI

### Project Overview

This project was created for learning purposes to understand how small language models (SLMs) work.
It uses the Whisper framework to transcribe audio into text and then passes that transcribed text to the LLaMA framework for inference.

For demonstration, the project uses TinyLlama and Qwen models to run locally and display the output on-device.

During testing, the models produced minor inaccuracies or unrelated outputs (hallucinations) only in rare cases. This behavior is typical for language models without fine-tuning. Fine-tuning on task-specific data could help improve accuracy.

### Working

Audio → Whisper → Transcription → LLaMA (TinyLlama/Qwen) → Output


### 🎥 Demo
Question asked: “How is AI helping humans? Do you think it is good?”

[Watch the demo - Qwen model](https://github.com/DhimanKaran/Voice2AI/raw/main/demo-videos/qwen-output.mp4)

[Watch the demo - TinyLlama model](https://github.com/DhimanKaran/Voice2AI/raw/main/demo-videos/tinyLlama-output.mp4)
