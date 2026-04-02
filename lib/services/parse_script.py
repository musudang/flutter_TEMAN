import re
import os

file_path = "c:/Users/user/OneDrive/Desktop/TEMAN FLUTTER TRIAL/teman_flutter_app_code/lib/services/firestore_service.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

sections = re.split(r'// ===================== (.*?) =====================', text)
print("Sections found:")
for i in range(1, len(sections), 2):
    print(sections[i])
