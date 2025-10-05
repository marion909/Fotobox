# Test Server Environment
import requests

SERVER_URL = "https://upload.neuhauser.cloud"

print("🔍 Testing Server Environment")
print("=" * 40)

# Test server info
try:
    print("1. Testing server info...")
    response = requests.get(f"{SERVER_URL}/server_info.php", timeout=10)
    
    if response.status_code == 200:
        print("✅ Server info accessible")
        print("\nServer Environment:")
        print(response.text)
    else:
        print(f"❌ Server info not accessible: {response.status_code}")
        
except Exception as e:
    print(f"❌ Error accessing server info: {e}")

# Test with a simple debug upload
print("\n" + "=" * 40)
print("2. Testing simple upload debug...")

import tempfile
import os
from PIL import Image

# Create simple test image
img = Image.new('RGB', (100, 100), color='red')
temp_file = os.path.join(tempfile.gettempdir(), 'simple_test.jpg')
img.save(temp_file, 'JPEG')

# Try upload with debug info
headers = {
    'Authorization': 'Bearer GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS'
}

with open(temp_file, 'rb') as f:
    files = {'photo': ('test.jpg', f, 'image/jpeg')}
    
    try:
        response = requests.post(f"{SERVER_URL}/upload.php", headers=headers, files=files, timeout=30)
        print(f"Status: {response.status_code}")
        print(f"Headers: {response.headers}")
        print(f"Response: {response.text[:1000]}")
        
    except Exception as e:
        print(f"Upload error: {e}")

# Cleanup
os.unlink(temp_file)