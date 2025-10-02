#!/bin/bash

# Voice Pipeline Test - Audio Upload Helper Script
# This script helps upload an audio file to the test PVC

echo "========================================"
echo "Voice Pipeline Test - Audio Upload Tool"
echo "========================================"
echo

# Check if audio file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-audio-file.wav>"
    echo
    echo "Example:"
    echo "  $0 /path/to/my-test-audio.wav"
    echo
    echo "Note: The audio file should be in WAV format"
    exit 1
fi

AUDIO_FILE="$1"

# Check if file exists
if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: File '$AUDIO_FILE' does not exist!"
    exit 1
fi

echo "Uploading file: $AUDIO_FILE"
echo "Target: voice-pipeline-test/upload-audio pod"
echo

# Upload the file
kubectl cp "$AUDIO_FILE" voice-pipeline-test/upload-audio:/audio-data/test-audio.wav

if [ $? -eq 0 ]; then
    echo "✓ File uploaded successfully!"
    echo
    echo "Verifying upload..."
    kubectl exec -n voice-pipeline-test upload-audio -- ls -lh /audio-data/
    echo
    echo "File is ready for testing!"
    echo
    echo "You can now:"
    echo "1. Delete the upload pod:"
    echo "   kubectl delete pod -n voice-pipeline-test upload-audio"
    echo
    echo "2. Manually trigger the test:"
    echo "   kubectl create job -n voice-pipeline-test test-run-manual --from=cronjob/voice-pipeline-test"
    echo
    echo "3. View the test logs:"
    echo "   kubectl logs -n voice-pipeline-test -l job-name=test-run-manual -f"
else
    echo "✗ Upload failed! Please check the error above."
    exit 1
fi
