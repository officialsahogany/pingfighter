#!/usr/bin/env python3
"""Quick test to see if game runs"""

import subprocess
import time

print("Starting game test...")
proc = subprocess.Popen(['python3', 'pingfighter.py'], 
                       stdout=subprocess.PIPE, 
                       stderr=subprocess.STDOUT,
                       text=True)

# Wait a bit
time.sleep(3)

# Check if still running
if proc.poll() is None:
    print("✅ Game is running without crashes")
    proc.terminate()
else:
    print("❌ Game crashed")
    output, _ = proc.communicate()
    print("Output:")
    print(output[-1000:])  # Last 1000 chars