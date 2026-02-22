import re

files = [
    r'lib\services\firestore_service.dart',
    r'lib\models\notification_model.dart'
]

pattern = re.compile(r"\(data\['([^']+)'\] as Timestamp\)\.toDate\(\)")
replacement = r"(data['\1'] as Timestamp?)?.toDate() ?? DateTime.now()"

for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = pattern.sub(replacement, content)
    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f'Fixed {fpath}')
