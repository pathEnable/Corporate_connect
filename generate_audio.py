import math
import wave
import struct
import os

os.makedirs("d:/Nouveau dossier/assets/audio", exist_ok=True)

def make_chime(filename):
    sample_rate = 44100
    # 2 seconds total, 0.5s sound, 1.5s silence for looping
    num_samples = int(2.0 * sample_rate)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        for i in range(num_samples):
            t = float(i) / sample_rate
            if t < 0.5:
                # Simple chord C5 + E5
                env = math.exp(-t * 5) # decay
                val = 0.3 * math.sin(2 * math.pi * 523.25 * t) + 0.3 * math.sin(2 * math.pi * 659.25 * t)
                value = int(32767.0 * val * env)
            else:
                value = 0
            wav_file.writeframes(struct.pack('<h', value))

make_chime("d:/Nouveau dossier/assets/audio/ringtone.wav")
print("Audio generated successfully.")
