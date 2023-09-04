# Todo: write the server code

# See scripts/tortoise_tts.py in the Tortoise TTS repo for all the various command-line options.

# Sample commands:
# /root/hay_say/.venvs/tortoise/bin/python3 scripts/tortoise_tts.py -v rainbow -o out.wav text "Hi There! My name is Rainbow."
#   This uses the alternative mode to "mimic" Rainbow's voice and doesn't do a convincing job.
# /root/hay_say/.venvs/tortoise/bin/python3 scripts/tortoise_tts.py -v train_grace -o out.wav text "Hi There! My name is Starlight Glimmer."
#   This uses an actual pretrained model and produces decent output that might be useful as input to so-vits-svc or RVC.

# Most of the models have noticeable british accents. train_dreams, train_grace, train_lescault, and maybe train_mouse
# are the only ones that don't.