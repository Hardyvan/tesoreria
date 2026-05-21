import urllib.request
import urllib.error
import json

url = 'https://api.insoft.com.pe/pollito/upload/api_tesoreria/index.php'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as res:
        print("Status Code:", res.getcode())
        print("Body:", res.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("HTTP Error:", e.code)
    print("Headers:", dict(e.headers))
    print("Body:", e.read().decode('utf-8', errors='ignore'))
except Exception as e:
    print("General Error:", e)
